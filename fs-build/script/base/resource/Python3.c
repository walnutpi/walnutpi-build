#include <unistd.h>

int main(int argc, char *argv[])
{
    execv("/usr/bin/python3", argv);
    return 0;
}
