# Don't forget to set the board options in the CMakeLists.txt in root src-dir

# Set PRJ_NAME to the directory name this is in!
set(PRJ_NAME combined)

# Add the sourcefiles of your project. The extensions are automatically found.
set(SRC combined.cpp test.c blinker.cpp)

# Some general rules
INCLUDE(../generic.cmake)
