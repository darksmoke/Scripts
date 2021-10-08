@echo off

for /f "delims=|" %%f in ('dir /B /A:D-H-R c:\users') do (rmdir "C:\Users\%%f\AppData\Local\1C\1cv8\" /s/q || del "C:\Users\%%f\AppData\Local\1C\1cv8\*" /s/q)
for /f "delims=|" %%f in ('dir /B /A:D-H-R c:\users') do (rmdir "C:\Users\%%f\AppData\Local\Google\" /s/q || del "C:\Users\%%f\AppData\Local\Google\*" /s/q)
for /f "delims=|" %%f in ('dir /B /A:D-H-R c:\users') do (rmdir "C:\Users\%%f\AppData\Local\Microsoft\Windows\INetCache\IE\" /s/q || del "C:\Users\%%f\AppData\Local\Microsoft\Windows\INetCache\IE\*" /s/q)
for /f "delims=|" %%f in ('dir /B /A:D-H-R c:\users') do (rmdir "C:\Users\%%f\AppData\Local\1C\1cv8\" /s/q || del "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp\s*" /s/q)
for /f "delims=|" %%f in ('dir /B /A:D-H-R c:\users') do (rmdir "C:\Users\%%f\AppData\Local\1C\1cv8\" /s/q || del "C:\Users\%%f\AppData\Local\Mozilla\Firefox\Profiles" /s/q)
