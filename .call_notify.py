import subprocess

with open('.notify_msg.txt', 'r') as f:
    msg = f.read()

result = subprocess.run(['./notify', msg], capture_output=True, text=True)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("RC:", result.returncode)
