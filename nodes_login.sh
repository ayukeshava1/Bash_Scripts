#!/bin/bash

# Input CSV file
CSV_FILE="input.csv"
# Log file for output
LOG_FILE="telnet_login.log"
# Temporary file to capture expect output
TEMP_FILE=$(mktemp /tmp/telnet_script.XXXXXX 2>/dev/null || echo "/tmp/telnet_script_$$")

# Check if temporary file was created successfully
if [[ -z "$TEMP_FILE" || ! -w "$(dirname "$TEMP_FILE")" ]]; then
  echo "Error: Failed to create temporary file." | tee -a "$LOG_FILE"
  exit 1
fi

# Check if input.csv exists
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: $CSV_FILE does not exist." | tee -a "$LOG_FILE"
  exit 1
fi

# Check if expect is installed
if ! command -v expect &> /dev/null; then
  echo "Error: expect is not installed. Please install it (e.g., sudo apt install expect)." | tee -a "$LOG_FILE"
  exit 1
fi

# Initialize log file
echo "Telnet Login Script Log - $(date)" > "$LOG_FILE"

# Read CSV file line by line
while IFS=, read -r ip username password; do
  # Skip empty lines or header
  [[ -z "$ip" || "$ip" == "ip" ]] && continue

  echo "Attempting to log in to $ip..." | tee -a "$LOG_FILE"

  # Expect script for Telnet automation
  /usr/bin/expect > "$TEMP_FILE" 2>&1 <<EOF
    set timeout 10
    spawn telnet $ip
    expect {
      "login:" {
        send "$username\r"
        expect {
          "Password:" {
            send "$password\r"
            expect {
              "#" {
                send "whoami\r"
                expect "#"
                sleep 5
                send "exit\r"
                expect eof
                puts "LOGIN_SUCCESS"
              }
              default {
                puts "Login failed for $ip: Invalid credentials"
                exit 1
              }
            }
          }
          default {
            puts "Login failed for $ip: No password prompt"
            exit 1
          }
        }
      }
      "Connection refused" {
        puts "Connection refused for $ip"
        exit 1
      }
      timeout {
        puts "Connection timed out for $ip"
        exit 1
      }
    }
EOF

  # Capture the exit status of expect
  EXPECT_STATUS=$?

  # Append expect output to log file
  if [[ -f "$TEMP_FILE" ]]; then
    cat "$TEMP_FILE" >> "$LOG_FILE"
  else
    echo "Error: Temporary file $TEMP_FILE not found." | tee -a "$LOG_FILE"
  fi

  # Check for LOGIN_SUCCESS in the output and the expect exit status
  if [[ $EXPECT_STATUS -eq 0 && -f "$TEMP_FILE" && $(grep -c "LOGIN_SUCCESS" "$TEMP_FILE") -gt 0 ]]; then
    echo "Successfully logged in and out of $ip" | tee -a "$LOG_FILE"
  else
    echo "Failed to log in to $ip" | tee -a "$LOG_FILE"
  fi

  # Clear the temporary file for the next iteration
  : > "$TEMP_FILE"

  # Small delay to prevent overwhelming the system
  sleep 1

done < "$CSV_FILE"

# Clean up temporary file
[[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"

echo "Script completed. Check $LOG_FILE for details."
