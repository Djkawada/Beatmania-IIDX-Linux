use anyhow::{Context, Result};
use clap::Parser;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::thread;
use std::time::Duration;

#[derive(Parser, Debug)]
#[command(author, version, about = "Native Rust XRPC Region & e-Amusement Fixer Proxy for Beatmania IIDX")]
struct Args {
    /// Proxy listen port (default: 8083)
    #[arg(short, long, default_value_t = 8083)]
    port: u16,

    /// Target Asphyxia Core port (default: 8084)
    #[arg(short, long, default_value_t = 8084)]
    target_port: u16,

    /// Listen IP address (default: 0.0.0.0)
    #[arg(short = 'H', long, default_value = "0.0.0.0")]
    host: String,
}

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).position(|window| window == needle)
}

fn replace_subslice(data: &mut Vec<u8>, from: &[u8], to: &[u8]) {
    let mut i = 0;
    while i + from.len() <= data.len() {
        if &data[i..i + from.len()] == from {
            data.splice(i..i + from.len(), to.iter().cloned());
            i += to.len();
        } else {
            i += 1;
        }
    }
}

fn handle_client(mut client_stream: TcpStream, target_port: u16, listen_port: u16) {
    let _ = client_stream.set_read_timeout(Some(Duration::from_millis(3000)));
    let _ = client_stream.set_nodelay(true);

    let target_addr = format!("127.0.0.1:{}", target_port);
    let mut server_stream = match TcpStream::connect(&target_addr) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("[-] [Proxy] Cannot connect to Asphyxia on {}: {}", target_addr, e);
            let response = "HTTP/1.1 502 Bad Gateway\r\nContent-Type: text/plain\r\nContent-Length: 42\r\n\r\nBad Gateway: Asphyxia Core not reachable";
            let _ = client_stream.write_all(response.as_bytes());
            return;
        }
    };

    let _ = server_stream.set_read_timeout(Some(Duration::from_millis(5000)));
    let _ = server_stream.set_nodelay(true);

    // Read full client request
    let mut req_buffer = Vec::new();
    let mut tmp_req = [0u8; 8192];
    loop {
        match client_stream.read(&mut tmp_req) {
            Ok(0) => break,
            Ok(n) => {
                req_buffer.extend_from_slice(&tmp_req[..n]);
                if let Some(pos) = find_subslice(&req_buffer, b"\r\n\r\n") {
                    let header_str = String::from_utf8_lossy(&req_buffer[..pos]);
                    let mut content_len = 0;
                    let mut has_content_len = false;
                    for line in header_str.lines() {
                        if line.to_lowercase().starts_with("content-length:") {
                            if let Ok(len) = line[15..].trim().parse::<usize>() {
                                content_len = len;
                                has_content_len = true;
                            }
                        }
                    }
                    let current_body_len = req_buffer.len() - (pos + 4);
                    if !has_content_len || current_body_len >= content_len {
                        break;
                    }
                }
            }
            Err(_) => {
                if find_subslice(&req_buffer, b"\r\n\r\n").is_some() {
                    break;
                }
                return;
            }
        }
    }

    if req_buffer.is_empty() {
        return;
    }

    let header_end = match find_subslice(&req_buffer, b"\r\n\r\n") {
        Some(pos) => pos,
        None => return,
    };

    let header_bytes = &req_buffer[..header_end];
    let body_bytes = &req_buffer[header_end + 4..];

    let header_str = String::from_utf8_lossy(header_bytes);
    let first_line = header_str.lines().next().unwrap_or("").to_string();

    // Prepare modified request headers:
    // 1. Point Host to Asphyxia target port
    // 2. Request uncompressed responses (x-compress: none, accept-encoding: identity) so we can parse & rewrite XML
    // 3. Ensure Connection: close
    let mut new_request_headers = Vec::new();
    for (i, line) in header_str.lines().enumerate() {
        let line_lower = line.to_lowercase();
        if i == 0 {
            new_request_headers.push(line.to_string());
        } else if line_lower.starts_with("host:") {
            new_request_headers.push(format!("Host: 127.0.0.1:{}", listen_port));
        } else if line_lower.starts_with("x-compress:") {
            new_request_headers.push("X-Compress: none".to_string());
        } else if line_lower.starts_with("accept-encoding:") {
            new_request_headers.push("Accept-Encoding: identity".to_string());
        } else if line_lower.starts_with("connection:") {
            new_request_headers.push("Connection: close".to_string());
        } else {
            new_request_headers.push(line.to_string());
        }
    }

    if !header_str.to_lowercase().contains("x-compress:") {
        new_request_headers.push("X-Compress: none".to_string());
    }
    if !header_str.to_lowercase().contains("accept-encoding:") {
        new_request_headers.push("Accept-Encoding: identity".to_string());
    }
    if !header_str.to_lowercase().contains("connection:") {
        new_request_headers.push("Connection: close".to_string());
    }

    let mod_headers_str = new_request_headers.join("\r\n");
    let mut mod_req_bytes = mod_headers_str.into_bytes();
    mod_req_bytes.extend_from_slice(b"\r\n\r\n");
    mod_req_bytes.extend_from_slice(body_bytes);

    if server_stream.write_all(&mod_req_bytes).is_err() {
        return;
    }

    // Read full response from Asphyxia
    let mut resp_buffer = Vec::new();
    let mut tmp_resp = [0u8; 8192];
    loop {
        match server_stream.read(&mut tmp_resp) {
            Ok(0) => break,
            Ok(read_n) => resp_buffer.extend_from_slice(&tmp_resp[..read_n]),
            Err(_) => break,
        }
    }

    if resp_buffer.is_empty() {
        return;
    }

    let resp_header_end = match find_subslice(&resp_buffer, b"\r\n\r\n") {
        Some(pos) => pos,
        None => {
            let _ = client_stream.write_all(&resp_buffer);
            return;
        }
    };

    let resp_header_bytes = &resp_buffer[..resp_header_end];
    let resp_body_bytes = &resp_buffer[resp_header_end + 4..];

    let resp_header_str = String::from_utf8_lossy(resp_header_bytes);
    let mut body_vec = resp_body_bytes.to_vec();

    // 1. Rewrite port numbers and hostnames safely at byte level
    let target_url1 = format!("http://127.0.0.1:{}/", target_port).into_bytes();
    let target_url1_n = format!("http://127.0.0.1:{}", target_port).into_bytes();
    let target_url2 = format!("http://localhost:{}/", target_port).into_bytes();
    let target_url2_n = format!("http://localhost:{}", target_port).into_bytes();
    let listen_url_slash = format!("http://127.0.0.1:{}/", listen_port).into_bytes();
    let listen_url = format!("http://127.0.0.1:{}", listen_port).into_bytes();

    replace_subslice(&mut body_vec, &target_url1, &listen_url_slash);
    replace_subslice(&mut body_vec, &target_url1_n, &listen_url_slash);
    replace_subslice(&mut body_vec, &target_url2, &listen_url_slash);
    replace_subslice(&mut body_vec, &target_url2_n, &listen_url_slash);
    replace_subslice(&mut body_vec, b"http://services.konami.net/", &listen_url_slash);
    replace_subslice(&mut body_vec, b"http://services.konami.net", &listen_url_slash);
    replace_subslice(&mut body_vec, b"http://eagate.573.jp/", &listen_url_slash);
    replace_subslice(&mut body_vec, b"http://eagate.573.jp", &listen_url_slash);
    replace_subslice(&mut body_vec, b"http://ea.573.jp/", &listen_url_slash);
    replace_subslice(&mut body_vec, b"http://eapass.573.jp/", &listen_url_slash);

    // Clean up any double trailing slashes
    let double_slash = format!("http://127.0.0.1:{}//", listen_port).into_bytes();
    replace_subslice(&mut body_vec, &double_slash, &listen_url_slash);

    // 2. Rewrite Country Code & Region for official Japanese LDJ cabinet validation
    replace_subslice(&mut body_vec, b"<country __type=\"str\">AX</country>", b"<country __type=\"str\">JP</country>");
    replace_subslice(&mut body_vec, b"<country>AX</country>", b"<country>JP</country>");
    replace_subslice(&mut body_vec, b"<countryname __type=\"str\">UNKNOWN</countryname>", b"<countryname __type=\"str\">JAPAN</countryname>");
    replace_subslice(&mut body_vec, b"<countryname>UNKNOWN</countryname>", b"<countryname>JAPAN</countryname>");
    
    // Shift-JIS & UTF-8 for 日本 (Japan)
    replace_subslice(&mut body_vec, b"<countryjname __type=\"str\">\x95\x73\x96\xbe</countryjname>", b"<countryjname __type=\"str\">\x93\xfa\x96\x7b</countryjname>");
    replace_subslice(&mut body_vec, b"<countryjname>\x95\x73\x96\xbe</countryjname>", b"<countryjname>\x93\xfa\x96\x7b</countryjname>");
    replace_subslice(&mut body_vec, "<countryjname __type=\"str\">不明</countryjname>".as_bytes(), "<countryjname __type=\"str\">日本</countryjname>".as_bytes());
    replace_subslice(&mut body_vec, "<countryjname>不明</countryjname>".as_bytes(), "<countryjname>日本</countryjname>".as_bytes());

    // 3. Ensure mode="operation" and status="0" on services response
    let is_services = find_subslice(&body_vec, b"<services").is_some();
    if is_services {
        let body_str_check = String::from_utf8_lossy(&body_vec).to_string();
        if !body_str_check.contains("mode=") {
            replace_subslice(&mut body_vec, b"<services", b"<services mode=\"operation\" status=\"0\"");
        }

        // List of essential services expected by IIDX
        let required_services = [
            "facility",
            "pcbtracker",
            "message",
            "pcbevent",
            "package",
            "eacoin",
            "cardmng",
            "userdata",
            "local",
            "local2",
        ];

        let mut missing_services = String::new();
        for svc in &required_services {
            if !body_str_check.contains(&format!("name=\"{}\"", svc)) {
                missing_services.push_str(&format!("<item name=\"{}\" url=\"http://127.0.0.1:{}/\"/>\n", svc, listen_port));
            }
        }

        if !missing_services.is_empty() {
            if let Some(pos) = find_subslice(&body_vec, b"</services>") {
                body_vec.splice(pos..pos, missing_services.into_bytes());
            }
        }
    }

    // 4. Ensure facility.get contains share/eacoin block
    let is_facility = find_subslice(&body_vec, b"<facility").is_some();
    if is_facility {
        let body_str_facility = String::from_utf8_lossy(&body_vec).to_string();
        if !body_str_facility.contains("<eacoin") {
            let eacoin_share = b"<share><eacoin><supplylimit __type=\"u32\">100000</supplylimit><holdlimit __type=\"u32\">100000</holdlimit></eacoin></share>";
            if let Some(pos) = find_subslice(&body_vec, b"</facility>") {
                body_vec.splice(pos..pos, eacoin_share.iter().cloned());
            }
        }
    }

    // Log request & response summary
    let first_resp_line = resp_header_str.lines().next().unwrap_or("");
    println!("[XRPC] {} -> {} ({} bytes)", first_line, first_resp_line, body_vec.len());

    let mut new_resp_headers = Vec::new();
    for line in resp_header_str.lines() {
        let line_lower = line.to_lowercase();
        if line_lower.starts_with("content-length:") {
            new_resp_headers.push(format!("Content-Length: {}", body_vec.len()));
        } else if line_lower.starts_with("x-compress:") {
            new_resp_headers.push("X-Compress: none".to_string());
        } else if line_lower.starts_with("transfer-encoding:") {
            // Drop chunked encoding since we send full content-length
            continue;
        } else {
            new_resp_headers.push(line.to_string());
        }
    }

    let mut final_resp = new_resp_headers.join("\r\n").into_bytes();
    final_resp.extend_from_slice(b"\r\n\r\n");
    final_resp.extend_from_slice(&body_vec);

    let _ = client_stream.write_all(&final_resp);
}

fn main() -> Result<()> {
    let args = Args::parse();

    let bind_addr = format!("{}:{}", args.host, args.port);
    let listener = TcpListener::bind(&bind_addr)
        .with_context(|| format!("Failed to bind XRPC proxy listener on {}", bind_addr))?;

    println!("\x1b[1;36m====================================================\x1b[0m");
    println!("\x1b[1;35m   BEATMANIA IIDX NATIVE RUST XRPC REGION FIXER     \x1b[0m");
    println!("\x1b[1;36m====================================================\x1b[0m");
    println!(
        "\x1b[32m[+] Native Rust Proxy active on http://{} -> Asphyxia Core on 127.0.0.1:{}\x1b[0m",
        bind_addr, args.target_port
    );

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let target_port = args.target_port;
                let listen_port = args.port;
                thread::spawn(move || handle_client(stream, target_port, listen_port));
            }
            Err(e) => {
                eprintln!("[-] Connection failed: {}", e);
            }
        }
    }

    Ok(())
}
