use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::net::UdpSocket;
use ringbuf::traits::{Split, Consumer, Producer};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let host = cpal::default_host();
    
    let devices = host.output_devices()?;
    let mut out_device = None;

    for device in devices {
        let name = device.name().unwrap_or_default();
        let lower_name = name.to_lowercase();
        // Priority: Motherboard but NOT loopback
        if (lower_name.contains("analog") || lower_name.contains("starship") || lower_name.contains("matisse")) 
           && !lower_name.contains("loopback") {
            println!("[!!!] Found Motherboard Output: {}", name);
            out_device = Some(device);
            break;
        }
    }

    let out_device = out_device.or_else(|| host.default_output_device())
        .expect("No physical audio device found!");

    let supported_config = out_device.default_output_config()?;
    let out_config: cpal::StreamConfig = supported_config.clone().into();

    println!("==================================================");
    println!("   IIDX RUST AUDIO SERVER (Socket Mode)");
    println!("==================================================");
    println!("Target Device: {}", out_device.name()?);

    let socket = UdpSocket::bind("127.0.0.1:44100")?;
    let rb = ringbuf::HeapRb::<i16>::new(65536);
    let (mut producer, mut consumer) = rb.split();

    let stream = out_device.build_output_stream(
        &out_config,
        move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
            for sample in data.iter_mut() {
                if let Some(s) = consumer.try_pop() {
                    *sample = ((s as f32) / 32768.0) * 0.5;
                } else {
                    *sample = 0.0;
                }
            }
        },
        |err| eprintln!("Audio Error: {}", err),
        None
    )?;

    stream.play()?;

    let mut buf = [0u8; 4096];
    loop {
        let (n, _) = socket.recv_from(&mut buf)?;
        let samples = unsafe {
            std::slice::from_raw_parts(buf.as_ptr() as *const i16, n / 2)
        };
        for &s in samples {
            while producer.try_push(s).is_err() {
                std::thread::yield_now();
            }
        }
    }
}
