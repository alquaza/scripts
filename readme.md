# Scripts for Alex's devices

Made by Alex (and Claude).

## Posture reminder

A macOS-only reminder that displays a pop-up after each hour of use while your laptop is awake. It resets after waking from sleep or screensavers. Click **Stop for today** to silence reminders until the next day.

To install, from this repository, run:

```sh
bash install-posture-reminder.sh
bash install-posture-reminder.sh test
```

The second command tests it by immediately putting out a pop-up.

The installer sets it to start at login, so you can delete the installer file afterward. For more information, to change the interval/message, or for other details, read the script file.
