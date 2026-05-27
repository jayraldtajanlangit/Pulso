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


