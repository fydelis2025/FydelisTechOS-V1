cmake_minimum_required(VERSION 3.16)
project(FydelisTechOSInstaller VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Desativa o entrypoint automático do Qt para evitar conflito de símbolos globais (__argc) com o MinGW do Windows
set(QT_DISABLE_WINMAIN_STDCALL ON)

find_package(Qt6 COMPONENTS Widgets Core Gui Network REQUIRED)

set(SOURCES
    src/main.cpp

    # Wizard
    src/installwizard.cpp
    src/installwizard.h

    # Páginas
    src/welcomepage.cpp
    src/welcomepage.h
    src/preparationpage.cpp
    src/preparationpage.h
    src/partitionpage.cpp
    src/partitionpage.h
    src/toolselectionpage.cpp
    src/toolselectionpage.h
    src/slideshowpage.cpp
    src/slideshowpage.h
    src/summarypage.cpp
    src/summarypage.h

    # Slides
    src/imageslideplayer.cpp
    src/imageslideplayer.h

    # Partição
    src/partitionmanager.cpp
    src/partitionmanager.h
    src/diskwidget.cpp
    src/diskwidget.h

    # Instalação
    src/installworker.cpp
    src/installworker.h

    # Catálogo
    src/tools.h
)

add_executable(fydelistechos-installer WIN32 ${SOURCES})
target_include_directories(fydelistechos-installer PRIVATE src)
target_link_libraries(fydelistechos-installer PRIVATE Qt6::Widgets Qt6::Core Qt6::Gui Qt6::Network shell32 ole32 advapi32)

install(TARGETS fydelistechos-installer RUNTIME DESTINATION /usr/local/bin)
install(FILES assets/fydelistechos.desktop DESTINATION /usr/share/applications)