mod encrypt;
use std::fs;
use std::io::{Read, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::time::Duration;
use std::{io, thread};

fn extract<'a>(text: &'a str, prefix: &'a str, suffix: &'a str) -> io::Result<&'a str> {
    let left = text.find(prefix);
    let right = text.find(suffix);
    if let (Some(l), Some(r)) = (left, right) {
        if l + prefix.len() < r {
            return Ok(&text[l + prefix.len()..r]);
        }
    }
    Err(io::ErrorKind::InvalidData.into())
}

fn portal_url(text: &str) -> Option<String> {
    for (start, _) in text.match_indices("http://") {
        let candidate = &text[start..];
        let path = match candidate.find("/eportal/index.jsp?") {
            Some(path) => path,
            None => continue,
        };
        if candidate[..path].chars().any(char::is_whitespace) {
            continue;
        }
        let end = candidate[path..]
            .find(|c: char| c.is_whitespace() || matches!(c, '\'' | '"' | '<' | '>'))
            .map(|offset| path + offset)
            .unwrap_or(candidate.len());
        return Some(candidate[..end].to_owned());
    }
    None
}

fn raw_http(host: &str, path: &str) -> io::Result<String> {
    let mut last_error = None;
    let mut stream = None;
    for address in (host, 80).to_socket_addrs()? {
        match TcpStream::connect_timeout(&address, Duration::from_secs(8)) {
            Ok(connected) => {
                stream = Some(connected);
                break;
            }
            Err(error) => last_error = Some(error),
        }
    }

    let mut stream = stream
        .ok_or_else(|| last_error.unwrap_or_else(|| io::ErrorKind::AddrNotAvailable.into()))?;
    stream.set_read_timeout(Some(Duration::from_secs(8)))?;
    stream.set_write_timeout(Some(Duration::from_secs(8)))?;
    write!(
        stream,
        "GET {} HTTP/1.1\r\nHost: {}\r\nUser-Agent: hust-network-login\r\nConnection: close\r\n\r\n",
        path, host
    )?;

    let mut bytes = Vec::new();
    stream.take(64 * 1024).read_to_end(&mut bytes)?;
    Ok(String::from_utf8_lossy(&bytes).into_owned())
}

fn discover_portal() -> io::Result<Option<String>> {
    let probes = [
        ("edge-http.microsoft.com", "/captiveportal/generate_204", ""),
        ("123.123.123.123", "/", ""),
        ("detectportal.firefox.com", "/success.txt", "success"),
        (
            "www.msftconnecttest.com",
            "/connecttest.txt",
            "Microsoft Connect Test",
        ),
    ];
    let mut last_error = None;

    for (host, path, online_marker) in probes {
        match raw_http(host, path) {
            Ok(response) => {
                if let Some(url) = portal_url(&response) {
                    println!("portal discovered through {host}");
                    return Ok(Some(url));
                }
                let status_204 = response
                    .lines()
                    .next()
                    .is_some_and(|line| line.contains(" 204 "));
                if status_204 || (!online_marker.is_empty() && response.contains(online_marker)) {
                    return Ok(None);
                }
                println!("unexpected discovery response from {host}");
            }
            Err(error) => {
                println!("discovery failed through {host}: {error}");
                last_error = Some(error);
            }
        }
    }

    Err(last_error.unwrap_or_else(|| io::ErrorKind::InvalidData.into()))
}

fn login(username: &str, password: &str) -> io::Result<()> {
    let portal_url = match discover_portal()? {
        Some(url) => url,
        None => return Ok(()),
    };

    let portal_ip = extract(&portal_url, "http://", "/eportal/index.jsp")?;
    println!("portal host: {portal_ip}");

    let mac = extract(&portal_url, "mac=", "&t=")?;

    let encrypt_pass = encrypt::encrypt_pass(format!("{}>{}", password, mac));

    let query_string = portal_url
        .split_once("/eportal/index.jsp?")
        .map(|(_, query)| query)
        .ok_or(io::ErrorKind::InvalidData)?;

    let query_string = urlencoding::encode(query_string);

    let body = format!(
        "userId={}&password={}&service=&queryString={}&passwordEncrypt=true",
        username, encrypt_pass, query_string
    );

    let login_url = format!("http://{}/eportal/InterFace.do?method=login", portal_ip);

    let resp = minreq::post(login_url)
        .with_body(body)
        .with_header(
            "Content-Type",
            "application/x-www-form-urlencoded; charset=UTF-8",
        )
        .with_header("Accept", "*/*")
        .with_header("User-Agent", "hust-network-login")
        .with_timeout(10)
        .send()
        .map_err(|e| {
            println!("portal boom! {}", e);
            io::ErrorKind::ConnectionRefused
        })?;

    let resp = resp.as_str().map_err(|e| {
        println!("invalid login resp format {}", e);
        io::ErrorKind::InvalidData
    })?;

    if resp.contains("success") {
        println!("portal login succeeded");
        Ok(())
    } else {
        println!("portal login was rejected");
        Err(io::ErrorKind::PermissionDenied.into())
    }
}

#[test]
fn extracts_portal_from_redirect_header() {
    let response = "HTTP/1.1 302 Found\r\nLocation: http://172.18.18.61:8080/eportal/index.jsp?wlanuserip=abc&mac=def&t=wireless-v2\r\n\r\n";
    assert_eq!(
        portal_url(response).unwrap(),
        "http://172.18.18.61:8080/eportal/index.jsp?wlanuserip=abc&mac=def&t=wireless-v2"
    );
}

#[test]
fn extracts_portal_from_script_body() {
    let response = "<script>top.self.location.href='http://172.18.18.61:8080/eportal/index.jsp?wlanuserip=abc&mac=def&t=wireless-v2'</script>";
    assert_eq!(
        portal_url(response).unwrap(),
        "http://172.18.18.61:8080/eportal/index.jsp?wlanuserip=abc&mac=def&t=wireless-v2"
    );
}

#[test]
#[ignore = "requires access to the HUST campus network"]
fn login_test() {
    let _ = login("username", "password");
}

struct Config {
    username: String,
    password: String,
}

impl Config {
    fn validate_and_assemble(
        username: Option<&str>,
        password: Option<&str>,
    ) -> Result<Self, &'static str> {
        match (username, password) {
            (Some(_), None) => Err("missing password"),
            (None, Some(_)) => Err("missing username"),
            (None, None) => Err("missing username and password"),
            (Some(username), Some(password)) => Ok(Self {
                username: username.to_owned(),
                password: password.to_owned(),
            }),
        }
    }

    pub fn from_env() -> Option<Self> {
        println!("reading configuration from environment variables");
        let username = std::env::var("HUST_NETWORK_LOGIN_USERNAME")
            .inspect_err(|err| println!("failed to read environment variable: {err}"))
            .ok();
        let password = std::env::var("HUST_NETWORK_LOGIN_PASSWORD")
            .inspect_err(|err| println!("failed to read environment variable: {err}"))
            .ok();

        let result = Self::validate_and_assemble(
            username.as_deref(),
            password.as_deref(),
        )
        .inspect_err(|err| println!("invalid configuration: {err}"))
        .ok()?;

        Some(result)
    }

    pub fn from_file(path: &str) -> Option<Self> {
        println!("reading configuration from file: {path}");

        let raw = fs::read(path)
            .inspect_err(|err| println!("failed to read from {path}: {err}"))
            .ok()?;

        let configuration = String::from_utf8(raw)
            .inspect_err(|err| println!("failed to parse content of {path}: {err}"))
            .ok()?;

        let mut lines = configuration.lines();
        let username = lines.next();
        let password = lines.next();
        let result = Self::validate_and_assemble(username, password)
            .inspect_err(|err| println!("invalid configuration: {err}"))
            .ok()?;

        Some(result)
    }

    pub fn from_args() -> Option<Self> {
        println!("reading configuration from arguments");

        let args = std::env::args();

        let path = args
            .skip(1) // skip executable path
            .last()
            .ok_or("at least 1 argument is required")
            .inspect_err(|err| println!("no configuration file specified: {err}"))
            .ok()?;

        Self::from_file(&path)
    }
}

fn main() {
    let config = Config::from_args()
        .or_else(Config::from_env)
        .or_else(|| Config::from_file("/etc/hust-network-login.conf"))
        .or_else(|| Config::from_file("/etc/hust-network-login/config"))
        .expect("no available configuration found");

    let run_once = std::env::var_os("HUST_NETWORK_LOGIN_ONCE").is_some();
    loop {
        let (success, delay) = match login(&config.username, &config.password) {
            Ok(_) => {
                println!("login ok. awaiting...");
                (true, 15)
            }
            Err(e) => {
                println!("error! {}", e);
                (false, 1)
            }
        };
        if run_once {
            if success {
                return;
            }
            std::process::exit(1);
        }
        thread::sleep(Duration::from_secs(delay));
    }
}
