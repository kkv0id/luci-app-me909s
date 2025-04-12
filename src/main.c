#include <stdio.h>    // printf, perror
#include <stdlib.h>   // exit, EXIT_FAILURE
#include <unistd.h>   // access, read, write, close
#include <string.h>   // strlen, strcpy, strcat, strstr, memset
#include <sys/time.h> // struct timeval, gettimeofday
#include <fcntl.h>
#include <termios.h>
#include <sys/select.h> // select, fd_set
#include <errno.h>      // errno, perror
#include "openDev.h"

int main(int argc, char **argv)
{
    if (argc < 3)
    {
        printf("ERROR demo: sendat /dev/ttyUSB1 'ATI'\n");
        return 1;
    }
    char *serial_dev = argv[1];
    if (access(serial_dev, F_OK) != 0)
    {
        fprintf(stderr, "serial device does not exist\n");
        return 1;
    }
    char *message = argv[2];
    char *nty = "\r\n";
    int timeout_sec = 0;
    if (argc >= 4)
    {
        sscanf(argv[3], "%d", &timeout_sec);
    }

    int fd = OpenDev(serial_dev);
    if (fd < 0)
    {
        perror("Can't Open Serial Port!\n");
        return 1;
    }

    set_speed(fd, 115200);
    if (set_Parity(fd, 8, 1, 'N') == FALSE)
    {
        perror("Set Parity Error\n");
        close(fd);
        return 1;
    }

    // 发送AT指令
    int messageLen = strlen(message);
    int ntyLen = strlen(nty);
    char sendAT[messageLen + ntyLen + 1];
    strcpy(sendAT, message);
    strcat(sendAT, nty);

    ssize_t wlen = write(fd, sendAT, strlen(sendAT));
    if (wlen < 0)
    {
        perror("write error");
        close(fd);
        return 1;
    }

    // 准备读取响应
    serial_parse phandle;
    phandle.rxbuffsize = 0;
    memset(phandle.buff, 0, MAX_BUFF_SIZE);

    struct timeval timeout;
    if (timeout_sec < 2)
    {
        timeout.tv_sec = 2; // 2秒超时
    }
    else
    {
        timeout.tv_sec = timeout_sec;
    }

    timeout.tv_usec = 0;

    fd_set read_fds;
    int ret;
    ssize_t nread;

    // 循环读取直到超时或收到完整响应
    do
    {
        FD_ZERO(&read_fds);
        FD_SET(fd, &read_fds);

        ret = select(fd + 1, &read_fds, NULL, NULL, &timeout);
        if (ret < 0)
        {
            perror("select error");
            close(fd);
            return 1;
        }
        else if (ret == 0)
        {
            fprintf(stderr, "timeout waiting for response\n");
            close(fd);
            return 1;
        }

        if (FD_ISSET(fd, &read_fds))
        {
            nread = read(fd, phandle.buff + phandle.rxbuffsize, MAX_BUFF_SIZE - phandle.rxbuffsize - 1);
            if (nread < 0)
            {
                perror("read error");
                close(fd);
                return 1;
            }
            else if (nread == 0)
            {
                break;
            }

            phandle.rxbuffsize += nread;
            // 检查是否缓冲区溢出
            if (phandle.rxbuffsize >= MAX_BUFF_SIZE - 1)
            {
                fprintf(stderr, "buffer overflow\n");
                close(fd);
                return 1;
            }

            if (strstr(phandle.buff, "OK\r\n") || strstr(phandle.buff, "ERROR"))
            {
                break;
            }
        }
    } while (1);

    printf("%s", phandle.buff);

    close(fd);
    return 0;
}