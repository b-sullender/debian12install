#include <stdio.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h> // for isspace

#define BUF_SIZE 256

// Function to get the type of drive (disk or partition)
char* get_drive_type(const char* drive_path) {
    char sys_path[256];
    snprintf(sys_path, sizeof(sys_path), "/sys/class/block/%s", drive_path);
    strcat(sys_path, "/partition");
    int fd = open(sys_path, O_RDONLY);
    if (fd != -1) {
        close(fd);
        return "part";
    }
    return "disk";
}

// Function to get the size of the drive
unsigned long long get_drive_size(const char* drive_path) {
    char sys_path[256];
    snprintf(sys_path, sizeof(sys_path), "/sys/class/block/%s/size", drive_path);
    int fd = open(sys_path, O_RDONLY);
    if (fd == -1) {
        return 0;
    }

    char buf[BUF_SIZE];
    ssize_t bytes_read = read(fd, buf, BUF_SIZE);
    close(fd);

    if (bytes_read <= 0) {
        perror("Error reading size file");
        return 0;
    }

    buf[bytes_read] = '\0';
    return strtoull(buf, NULL, 10) * 512; // Block size is typically 512 bytes
}

// Function to get the model name of the drive
void get_drive_model(const char* drive_path, char* model) {
    char sys_path[256];
    snprintf(sys_path, sizeof(sys_path), "/sys/class/block/%s/device/model", drive_path);
    FILE* file = fopen(sys_path, "r");
    if (file == NULL) {
        strcpy(model, "Unknown");
        return;
    }

    if (fgets(model, BUF_SIZE, file) == NULL) {
        perror("Error reading model file");
        strcpy(model, "Unknown");
    }

    fclose(file);

    // Trim trailing whitespace and newline characters
    size_t len = strlen(model);
    while (len > 0 && (isspace(model[len - 1]) || model[len - 1] == '\n')) {
        model[len - 1] = '\0';
        len--;
    }
}

// Function to convert size to human-readable format
void format_size(unsigned long long size, char *output) {
    const char* units[] = {"B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"};
    int i = 0;
    double bytes = size;

    while (bytes >= 1024 && i < (sizeof(units) / sizeof(units[0])) - 1) {
        bytes /= 1024;
        i++;
    }

    sprintf(output, "%.2f %s", bytes, units[i]);
}

int main() {
    struct dirent *entry;
    DIR *dir = opendir("/dev");
    if (dir == NULL) {
        perror("Error opening directory");
        return 1;
    }

    printf("%-10s %-6s %-20s %-10s\n", "Drive", "Type", "Model", "Size");

    while ((entry = readdir(dir)) != NULL) {
        struct stat file_stat;
        char path[256];
        sprintf(path, "/dev/%s", entry->d_name);
        if (stat(path, &file_stat) == 0 && S_ISBLK(file_stat.st_mode)) {
            char* drive_type = get_drive_type(entry->d_name);
            unsigned long long drive_size = get_drive_size(entry->d_name);
            char model[BUF_SIZE];
            get_drive_model(entry->d_name, model);
            char formatted_size[20];
            format_size(drive_size, formatted_size);
            if (strcmp(drive_type, "disk") == 0 && drive_size != 0) {
                printf("%-10s %-6s %-20s %-10s\n", entry->d_name, drive_type, model, formatted_size);
            }
        }
    }

    closedir(dir);
    return 0;
}

