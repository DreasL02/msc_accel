DPI_LIB_NAME = libboard_socket.so
DPI_LIB = lib/$(DPI_LIB_NAME)

CC = g++
CFLAGS = -Wall -m64 -g -fPIC  -std=c++11
INCLUDES = -I. -I$(VCS_HOME)/include
SRCS = board_model.cpp
OBJS = $(SRCS:.cpp=.o)
TARGET = $(DPI_LIB)

.PHONY: all clean

all: $(TARGET)
	@echo Successfully compiled $(DPI_LIB_NAME)

$(TARGET): $(OBJS)
	@mkdir -p lib
	$(CC) $(CFLAGS) $(INCLUDES) -shared -o $(TARGET) $(OBJS)

.cpp.o:
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

clean:
	$(RM) *.o $(TARGET)
