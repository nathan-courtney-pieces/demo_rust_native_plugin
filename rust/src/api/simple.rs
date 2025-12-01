/// Simple greeting function
pub fn greet(name: String) -> String {
    format!("Hello, {}! 🦀", name)
}

/// Calculate Fibonacci number
pub fn calculate_fibonacci(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0u64;
            let mut b = 1u64;
            for _ in 2..=n {
                let temp = a + b;
                a = b;
                b = temp;
            }
            b
        }
    }
}

/// Add two numbers (example with multiple parameters)
pub fn add_numbers(a: i64, b: i64) -> i64 {
    a + b
}
