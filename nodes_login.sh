#!/bin/bash

# Input CSV file
CSV_FILE="input.csv"
# Log file for output
LOG_FILE="telnet_login.log"

# Check if input.csv exists
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: $CSV_FILE does not exist."
  exit 1
fi

# Check if expect is installed
if ! command -v expect &> /dev/null; then
  echo "Error: expect is not installed. Please install it (e.g., sudo apt install expect)."
  exit 1
fi

# Initialize log file
echo "Telnet Login Script Log - $(date)" > "$LOG_FILE"

# Read CSV file line by line
while IFS=, read -r ip username password; do
  # Skip empty lines or header
  [[ -z "$ip" || "$ip" == "ip" ]] && continue

  echo "Attempting to log in to $ip..." >> "$LOG_FILE"
  echo "Attempting to log in to $ip..."

  # Run expect and capture output and exit status
  OUTPUT=$(/usr/bin/expect 2>&1 <<EOF
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
  )
  EXPECT_STATUS=$?

  # Log the expect output
  echo "$OUTPUT" >> "$LOG_FILE"

  # Check for LOGIN_SUCCESS in the output and the expect exit status
  if [[ $EXPECT_STATUS -eq 0 && "$OUTPUT" =~ LOGIN_SUCCESS ]]; then
    echo "Successfully logged in and out of $ip" | tee -a "$LOG_FILE"
  else
    echo "Failed to log in to $ip" | tee -a "$LOG_FILE"
  fi

  # Small delay to prevent overwhelming the system
  sleep 1

done < "$CSV_FILE"

echo "Script completed. Check $LOG_FILE for details."
