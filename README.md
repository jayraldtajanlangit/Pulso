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

<img width="402" height="821" alt="Screenshot 2026-05-28 at 9 16 19 PM" src="https://github.com/user-attachments/assets/6016aec3-de92-427d-9440-8674a4379f9d" />

<img width="389" height="810" alt="Screenshot 2026-05-28 at 9 16 39 PM" src="https://github.com/user-attachments/assets/633b904d-ad1f-4c19-95e3-894d5a5c9cdb" />

<img width="388" height="819" alt="Screenshot 2026-05-28 at 9 17 02 PM" src="https://github.com/user-attachments/assets/5424c6f7-9366-48f6-8bb0-acb9abee5229" />

<img width="397" height="827" alt="Screenshot 2026-05-28 at 9 17 13 PM" src="https://github.com/user-attachments/assets/bff4c985-7b3c-49b8-83d2-46f18d76be36" />

<img width="360" height="805" alt="Screenshot 2026-05-28 at 9 17 23 PM" src="https://github.com/user-attachments/assets/fcfa80a0-aa72-4ebf-bffb-c55dc90cc07e" /># PULSO - Community Social App

<img width="395" height="828" alt="Screenshot 2026-05-28 at 9 17 58 PM" src="https://github.com/user-attachments/assets/b85465ad-1b3e-452c-915d-0c19b9e8ceb7" />

<img width="400" height="820" alt="Screenshot 2026-05-28 at 9 18 10 PM" src="https://github.com/user-attachments/assets/ea3ff358-912f-47f2-ac8c-b2adcb8ae4f6" />

<img width="1196" height="822" alt="Screenshot 2026-05-28 at 9 18 30 PM" src="https://github.com/user-attachments/assets/9b0554e5-434d-40b6-864e-9b0d1fbf0aa0" /> 

<img width="409" height="819" alt="Screenshot 2026-05-28 at 9 30 31 PM" src="https://github.com/user-attachments/assets/1dda1d97-7157-40c5-9751-5e3c203912e5" />

<img width="404" height="813" alt="Screenshot 2026-05-28 at 9 30 41 PM" src="https://github.com/user-attachments/assets/fa82eee1-18ab-4a1c-93d8-d679e51f9e9f" />









