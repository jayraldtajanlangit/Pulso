# PULSO - Community Social App

### Group Members: 

- Tajanlangit, Jayrald
- Diwa, Francis Marc Nikko
- Nombrado, John Cale N.
- Rostata, Josh

## Setup Instructions:

### Supabase environment variable setup (.env or --dart-define):

To avoid configuration mismatches and typing long commands, we use automated scripts to inject our Supabase keys dynamically.

### For macOS and Linux (Shell Script)

1. Create a file named `run.sh` in your root directory:
```bash
#!/bin/bash
flutter run \
  --dart-define=SUPABASE_URL="your_supabase_project_url" \
  --dart-define=SUPABASE_ANON_KEY="your_supabase_anon_key"
```

2. Give the script permission and execute it from your terminal:
```bash
chmod +x run.sh
./run.sh
```

---

### For Windows (Batch Script)

1. Create a file named `run.bat` in your root directory:
```cmd
@echo off
flutter run ^
  --dart-define=SUPABASE_URL="your_supabase_project_url" ^
  --dart-define=SUPABASE_ANON_KEY="your_supabase_anon_key"
```

2. Execute it from your Command Prompt or PowerShell:
```cmd
.\run.bat
```
> ⚠️ **Security Note:** To prevent unauthorized access and potential abuse, our live Supabase API keys and URLs are kept private and are **not** committed to this public repository. 

### 🔐 How to get the Credentials:
* **For Faculty/Evaluators:** Please contact any of the group members (Jayrald, Francis, John Cale, or Josh) via [MS Teams/Canvas/Email] to request the live `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
* Once received, replace the placeholder text (`your_supabase_project_url` and `your_supabase_anon_key`) in your local `run.sh` or `run.bat` file before launching the app.

## Screenshots of the app:

<img width="388" height="778" alt="Screenshot 2026-05-28 at 6 21 56 PM" src="https://github.com/user-attachments/assets/5a325b73-feec-4734-9727-62a7cfbf6f91" />

<img width="370" height="781" alt="Screenshot 2026-05-28 at 6 22 18 PM" src="https://github.com/user-attachments/assets/11ae525e-3429-41f6-bd9c-f2a566186fb9" />

<img width="384" height="782" alt="Screenshot 2026-05-28 at 6 22 41 PM" src="https://github.com/user-attachments/assets/c24e7344-9116-4b00-8a1c-fedacd0e6ddd" />

<img width="386" height="794" alt="Screenshot 2026-05-28 at 6 23 04 PM" src="https://github.com/user-attachments/assets/d3a97bbf-7694-4e78-95b6-7ac6aada4166" />

<img width="375" height="790" alt="Screenshot 2026-05-28 at 6 23 15 PM" src="https://github.com/user-attachments/assets/e2f01aae-c9be-4338-90d9-cf008aaeb7dd" />

<img width="374" height="783" alt="Screenshot 2026-05-28 at 6 23 32 PM" src="https://github.com/user-attachments/assets/c2e03540-a9f9-4ca6-8756-1ccca8906854" />

<img width="381" height="785" alt="Screenshot 2026-05-28 at 6 23 55 PM" src="https://github.com/user-attachments/assets/03c35285-5f94-4de6-8ba0-c7f23f578fc0" />

<img width="379" height="785" alt="Screenshot 2026-05-28 at 6 24 13 PM" src="https://github.com/user-attachments/assets/60083a73-c3ae-483b-a57c-518d4da0d819" />






