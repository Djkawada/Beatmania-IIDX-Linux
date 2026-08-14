use anyhow::{Context, Result};
use clap::Parser;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleRate, StreamConfig};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

#[derive(Parser, Debug)]
#[command(author, version, about = "Native Linux 44.1kHz Sound Bridge & Latency Lock for Beatmania IIDX")]
struct Args {
    /// Desired sample rate in Hz (default: 44100)
    #[arg(short, long, default_value_t = 44100)]
    rate: u32,

    /// Buffer quantum size in samples (default: 256)
    #[arg(short, long, default_value_t = 256)]
    buffer: u32,

    /// Keep audio stream active to lock PipeWire / ALSA sample rate
    #[arg(short, long, default_value_t = true)]
    lock_pipewire: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    println!("\x1b[1;36m====================================================\x1b[0m");
    println!("\x1b[1;35m      BEATMANIA IIDX NATIVE RUST SOUND BRIDGE       \x1b[0m");
    println!("\x1b[1;36m====================================================\x1b[0m");

    // 1. Force PipeWire quantum / rate via pw-metadata if available
    println!("\x1b[32m[+] Setting PipeWire audio rate to {}Hz (Quantum: {} samples)...\x1b[0m", args.rate, args.buffer);
    let _ = Command::new("pw-metadata")
        .args(["-n", "settings", "0", "clock.force-rate", &args.rate.to_string()])
        .status();
    let _ = Command::new("pw-metadata")
        .args(["-n", "settings", "0", "clock.force-quantum", &args.buffer.to_string()])
        .status();

    // 2. Query CPAL audio devices
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .context("No default audio output device found on Linux host")?;

    let device_name = device.name().unwrap_or_else(|_| "Unknown Device".to_string());
    println!("\x1b[32m[+] Audio Output Device:\x1b[0m {}", device_name);

    // 3. Find target config
    let supported_configs = device.supported_output_configs()
        .context("Failed to query supported audio output configs")?;

    let mut target_config = None;
    for config in supported_configs {
        if config.min_sample_rate() <= SampleRate(args.rate)
            && config.max_sample_rate() >= SampleRate(args.rate)
        {
            target_config = Some(config.with_sample_rate(SampleRate(args.rate)));
            break;
        }
    }

    let config: StreamConfig = match target_config {
        Some(c) => c.into(),
        None => {
            println!("\x1b[33m[*] {}Hz not explicitly advertised; fallback to default config\x1b[0m", args.rate);
            device.default_output_config()?.into()
        }
    };

    println!(
        "\x1b[32m[+] Stream Configuration:\x1b[0m {} channels, sample_rate: {}Hz, format: F32",
        config.channels, config.sample_rate.0
    );

    // 4. Build a silent low-latency stream to keep PipeWire hardware clock active & locked
    let stream_err_fn = |err| eprintln!("Audio stream error: {}", err);
    let sample_rate = config.sample_rate.0 as f32;

    let mut sample_clock = 0f32;
    let channels = config.channels as usize;

    let stream = device.build_output_stream(
        &config,
        move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
            // Write subtle silence (or clock anchor)
            for frame in data.chunks_mut(channels) {
                sample_clock = (sample_clock + 1.0) % sample_rate;
                for sample in frame.iter_mut() {
                    *sample = 0.0; // Clean silence, keeps sound card DAC initialized
                }
            }
        },
        stream_err_fn,
        None,
    )?;

    stream.play().context("Failed to start audio stream")?;
    println!("\x1b[1;32m[+] Audio Bridge active & locked at {}Hz! Low-latency sound ready for IIDX.\x1b[0m", args.rate);

    // 5. Graceful shutdown handler
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    ctrlc::set_handler(move || {
        println!("\n\x1b[33m[*] Sound bridge shutting down... resetting PipeWire rate lock.\x1b[0m");
        let _ = Command::new("pw-metadata")
            .args(["-n", "settings", "0", "clock.force-rate", "0"])
            .status();
        r.store(false, Ordering::SeqCst);
    })?;

    while running.load(Ordering::SeqCst) {
        thread::sleep(Duration::from_millis(250));
    }

    Ok(())
}
