# Cotowari

A statically typed script language that transpile into POSIX sh

## Installation

See [installation.md](docs/installation.md)

## How to use

```
# compile
ric examples/add.ri

# execution
ric examples/add.ri | sh
# or
ric run examples/add.ri
```

## Example

```
fn fib(n int) int {
  if n < 2 {
    return n
  }
  return fib(n - 1) + fib(n - 2)
}

fn twice() int {
    let n = read() as int
    return n * 2
}

assert fib(6) == 8
assert (fib(6) | twice()) == 16
```

[There is more examples](./examples)

## Development

See [docs/development.md](./docs/development.md)

### Docker

```
docker compose run dev
```
