# 1. Instalar Qt com MinGW
#    Qt online installer → Qt 5.15.x → MinGW 8.1.0 64-bit

# 2. No PowerShell ou CMD:
C:\Qt\5.15.2\mingw81_64\bin\qtenv2.bat

# 3. Compilar
mkdir build
cd build
cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
mingw32-make -j4

# 4. Copiar DLLs necessárias para junto do .exe
C:\Qt\5.15.2\mingw81_64\bin\windeployqt.exe fydelistechos-installer.exe

# 5. Executar
fydelistechos-installer.exe