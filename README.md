# PaSh Characterization

This repository evaluates the PaSh sytem using the [Koala](https://github.com/binpash/benchmarks) benchmarks for the shell. To run the benchmarks with PaSh, first install PaSh by following the instructions below. Then, set the `KOALA_SHELL` environment variable to point to the pa.sh executable:

To spin up and attach to the docker container with the local koala-pash dir
mounted

```bash
docker build -t koalapash .
docker run -it -v .:/srv koalapash
```


```bash
export KOALA_SHELL="/path/to/pash/pa.sh -d 1 -p -w 4"
```

## Instructions
To setup PaSh, run: 
```bash
./setup_pash.sh [OPTIONS]
```
The script will:
- Install required system packages and Python dependencies.
- Set up a Python virtual environment.
- Apply a patch to `sh-expand`, which is required to run PaSh with the suite.
- Optionally accept arguments, which will be passed as options to the PaSh shell (e.g., `-width 4`)

The top-level main.sh script is a quick script for downloading dependencies and inputs, running, profiling, and verifying a single Koala benchmark.

```bash
./main.sh <BENCHMARK_NAME> [OPTIONS] [<args passed to execute.sh>]
```

For more information and context on the benchmarks used, please visit the [Koala](https://github.com/binpash/benchmarks) repository.

## License
The Koala Benchmarks are licensed under the MIT License. See the LICENSE file for more information.
