#include <unistd.h>

int main(int argc, char *argv[])
{
    execv("/usr/bin/python", argv);
    return 0;
}
