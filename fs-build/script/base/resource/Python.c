#include <unistd.h>


// int main(int argc, char *argv[])
// {
//     execv("/usr/bin/python3", argv);
//     return 0;
// }


int main(int argc, char *argv[])
{
    char *new_argv[argc + 2];

    new_argv[0] = "/usr/bin/sudo";
    new_argv[1] = "/usr/bin/python";

    for (int i = 1; i < argc; i++) {
        new_argv[i + 1] = argv[i];
    }

    new_argv[argc + 1] = NULL;

    execv(new_argv[0], new_argv);

    return 0;
}
