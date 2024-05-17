#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <linux/wireless.h>
#include <string.h>

// Function to check if the interface is wireless
int is_wireless(const char *ifname) {
    int sock;
    struct iwreq wrq;

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == -1) {
        perror("socket");
        return -1;
    }

    strncpy(wrq.ifr_name, ifname, IFNAMSIZ);
    if (ioctl(sock, SIOCGIWNAME, &wrq) != -1) {
        close(sock);
        return 1; // Wireless interface
    }

    close(sock);
    return 0; // Not a wireless interface
}

int main() {
    struct if_nameindex *if_ni, *i;

    if_ni = if_nameindex();
    if (if_ni == NULL) {
        perror("if_nameindex");
        return 1;
    }

    printf("Network interfaces:\n");
    for (i = if_ni; i->if_name != NULL; i++) {
        printf("%s", i->if_name);
        if (is_wireless(i->if_name)) {
            printf(" (Wireless)\n");
        } else {
            printf(" (Wired)\n");
        }
    }

    if_freenameindex(if_ni);

    return 0;
}

