# cronwrap.sh

cronwrap.sh is a simple Bash script designed to act as a wrapper for cron jobs, providing error handling, timeout detection, and notification via email when a cron job fails or exceeds its allowed execution time. The email reports are sent in markdown format for better readability.

If you prefer a messenger notification then you can combine this system with [mailrise](https://github.com/YoRyan/mailrise).
For combining this shell script with mailrise I recommend to install a open-mail-relay like `bsd-mailx`.
You can check the mailrise directory for ansible installation instructions including the docker-compose configuration of mailrise.

## Inspired by this python project

<https://github.com/Doist/cronwrap/tree/master>

## Features

- Error Reporting: Captures command failures and sends an email report.
- Timeout Detection: Monitors the execution time of a cron job and sends a timeout notification if it exceeds the set time limit.
- Verbose Mode: Sends a success notification upon successful job completion if verbose mode is enabled.
- Email Alerts: Supports sending reports to one or multiple email addresses.
- Markdown Formatting: Email notifications are sent using markdown format for structured and readable reports.
- KISS: Keep it simple stupid
- No additional Runtime required (other than pure bash)

## Installation

1. Clone the repository to your local machine:

    ```bash
    git clone git@github.com:Entepotenz/cronwrapper_sh.git
    cd cronwrapper_sh/src/
    ```

1. Make the script executable:

    ```bash
    chmod +x cronwrap.sh
    ```

1. Optionally, move the script to a directory in your `$PATH` for easy execution:

    ```bash
    sudo mv cronwrap.sh /usr/local/bin/
    ```

1. Test with a Basic Command

    ```bash
    ./cronwrap.sh -c "ls -la" -e "your_email@example.com" -v
    ```

1. Integrate with crontab

    ```bash
    0 0 * * * /path/to/cronwrap.sh -c "/path/to/daily_task.sh" -e "your_email@example.com" -t "10m" -v
    ```

## Usage

```bash
./cronwrap.sh -c "command_to_run" [-e "email@example.com"] [-t "timeout"] [-v]
```

### Options

- `-c` / `--cmd` : The command to be wrapped and monitored. For example, -c "ls -la".
- `-e` / `--emails` : Comma-separated list of email addresses to send reports. Example: `-e "cron@example.com,johndoe@example.com"`.
- `-t` / `--max_time` : Set the maximum execution time for the command. Time can be specified in seconds (`s`), minutes (`m`), or hours (`h`). Example: `-t "2m"` (for 2 minutes).
- `-v` / `--verbose` : Send an email or print output on successful job execution.

### Usage Examples

```bash
cronwrap -c "sleep 2" -t "1s" -e cron@my_domain.com
````

```bash
cronwrap -c "blah" -t "1s" -e cron@my_domain.com
````

```bash
cronwrap -c "ls" -e cron@my_domain.com
````

```bash
cronwrap -c "ls" -e cron@my_domain.com -v
```
