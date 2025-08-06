#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_system.h"
#include "nvs_flash.h"

// Component includes
#include "common_types.h"
#include "stepper_motor.h"
#include "ble_peripheral.h"
#include "gatt_svr.h"
#include "motor_test.h"

static const char *TAG = "MAIN";

// Global motor instance
static stepper_motor_t g_motor = {
    .ain1_pin = DEFAULT_MOTOR_AIN1,
    .ain2_pin = DEFAULT_MOTOR_AIN2,
    .bin1_pin = DEFAULT_MOTOR_BIN1,
    .bin2_pin = DEFAULT_MOTOR_BIN2,
    .sleep_pin = DEFAULT_MOTOR_SLEEP,
    .fault_pin = DEFAULT_MOTOR_FAULT
};

// System status
static system_status_t system_status = SYSTEM_STATUS_INIT;

// Function to initialize NVS
static esp_err_t init_nvs(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    return ret;
}

// Function to initialize motor
static esp_err_t init_motor(void) {
    ESP_LOGI(TAG, "Initializing stepper motor...");
    
    esp_err_t ret = stepper_motor_init(&g_motor);
    if (ret != ESP_OK) {
     /   ESP_LOGE(TAG, "Failed to initialize motor: %s", esp_err_to_name(ret));
        return ret;
    }
    
    ESP_LOGI(TAG, "Motor initialized successfully");
    return ESP_OK;
}

// Function to initialize BLE
static esp_err_t init_ble(void) {
    ESP_LOGI(TAG, "Initializing BLE peripheral...");
    
    esp_err_t ret = ble_peripheral_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize BLE: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Set motor instance for GATT servexa
    gatt_svr_set_motor(&g_motor);
    
    ESP_LOGI(TAG, "BLE initialized successfully");
    return ESP_OK;
}

// Function to run motor tests (optional)
static void run_motor_tests(void) {
    ESP_LOGI(TAG, "=== Starting Motor Test Suite ===");
    system_status = SYSTEM_STATUS_TESTING;
    
    esp_err_t ret = motor_test_suite(&g_motor);
    if (ret == ESP_OK) {
        ESP_LOGI(TAG, "=== All Motor Tests Passed! ===");
    } else {
        ESP_LOGE(TAG, "=== Motor Test Suite Failed ===");
    }
    
    system_status = SYSTEM_STATUS_READY;
}

// Main application task
static void app_main_task(void *pvParameters) {
    ESP_LOGI(TAG, "Main application task started");
    
    while (1) {
        // Monitor system status
        switch (system_status) {
            case SYSTEM_STATUS_READY:
                // Check for motor faults
                if (stepper_motor_is_fault(&g_motor)) {
                    ESP_LOGE(TAG, "Motor fault detected!");
                    system_status = SYSTEM_STATUS_ERROR;
                }
                
                // Log BLE connection status periodically
                static int log_counter = 0;
                if (++log_counter >= 100) { // Every 10 seconds
                    log_counter = 0;
                    if (ble_peripheral_is_connected()) {
                        ESP_LOGI(TAG, "BLE connected, handle: %d", ble_peripheral_get_conn_handle());
                    } else {
                        ESP_LOGI(TAG, "BLE advertising, waiting for connection...");
                    }
                    
                    // Log motor status
                    motor_status_t motor_status = stepper_motor_get_status(&g_motor);
                    int16_t position = stepper_motor_get_position(&g_motor);
                    ESP_LOGI(TAG, "Motor status: %d, position: %d", motor_status, position);
                }
                break;
                
            case SYSTEM_STATUS_ERROR:
                ESP_LOGE(TAG, "System in error state");
                // Attempt to recover from error
                vTaskDelay(pdMS_TO_TICKS(5000));
                if (!stepper_motor_is_fault(&g_motor)) {
                    ESP_LOGI(TAG, "Fault cleared, returning to ready state");
                    system_status = SYSTEM_STATUS_READY;
                }
                break;
                
            case SYSTEM_STATUS_TESTING:
                // Do nothing while tests are running
                break;
                
            default:
                break;
        }
        
        // Task delay
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void app_main(void) {
    ESP_LOGI(TAG, "===== ESP32 Stepper Motor Controller Starting =====");
    ESP_LOGI(TAG, "Device: %s", DEVICE_NAME);
    ESP_LOGI(TAG, "Version: %s", FIRMWARE_VERSION);
    
    esp_err_t ret;
    
    // Initialize NVS
    ESP_LOGI(TAG, "Initializing NVS...");
    ret = init_nvs();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize NVS: %s", esp_err_to_name(ret));
        return;
    }
    
    // Initialize motor
    ret = init_motor();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Motor initialization failed, cannot continue");
        return;
    }
    
    // Initialize BLE
    ret = init_ble();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "BLE initialization failed, cannot continue");
        return;
    }
    
    // System is ready
    system_status = SYSTEM_STATUS_READY;
    ESP_LOGI(TAG, "===== System Initialization Complete =====");
    
    // Run motor tests (comment out if not needed)
    #ifdef CONFIG_ENABLE_MOTOR_TESTS
    run_motor_tests();
    #endif
    
    // Create main application task
    xTaskCreate(app_main_task, "app_main_task", 4096, NULL, 5, NULL);
    
    ESP_LOGI(TAG, "===== System Running =====");
    ESP_LOGI(TAG, "BLE device name: %s", BLE_DEVICE_NAME);
    ESP_LOGI(TAG, "Connect with a BLE client to control the motor");
    ESP_LOGI(TAG, "LED1: Motor activity, LED2: Enable status, LED3: Home command, LED4: Stop command");
}
