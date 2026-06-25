DPI_LIB_NAME= lib.so
DPI_LIB = lib/$(DPI_LIB_NAME)

# rest of makefile inspired by https://gist.github.com/fbartolic/6b3c6ea3c84647b795f24a245e7959f5

CC = g++ # define the C/C++ compiler to use
CFLAGS = -Wall -m64 -g -fPIC -std=c++11
# define any directories containing header files other than /usr/include
INCLUDES = -I. -I$(VCS_HOME)/include
# define the C++ source files
SRCS = client.cpp
# define the C/C++ object files
# This uses Suffix Replacement within a macro:
#   $(name:string1=string2)
#         For each word in 'name' replace 'string1' with 'string2'
OBJS = $(SRCS:.cpp=.o)
# define the shared library name
TARGET = $(DPI_LIB)

.PHONY: clean

all:    $(TARGET)
	@echo  Successfully compiled a .so library.

# compile object file to .so shared library
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(INCLUDES) -shared -o $(TARGET) $(OBJS)

# compile source files to object files

# this is a suffix replacement rule for building .o's from .c's
# it uses automatic variables $<: the name of the prerequisite of
# the rule(a .c file) and $@: the name of the target of the rule (a .o file)
# (see the gnu make manual section about automatic variables)
.cpp.o:
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@
clean:
	$(RM) *.o