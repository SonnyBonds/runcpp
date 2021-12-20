# runcpp
Small util for compiling &amp; running cpp-files in one step

# Usage (Windows, Linux & macOS)
`./runcpp input.cpp [arguments to pass to compiled executable]`

# Details
On Windows an exe called input.cpp.exe will be created.
On Linux/macOS a binary called input.cppx will be created.

The Linux/macOS version assumes the compiler environment is decently set up.
On Windows some deeper digging is done if an compiler environment isn't automatically found.

# Disclaimer
This whole thing is currently pretty cursed and mostly trying out a concept.
