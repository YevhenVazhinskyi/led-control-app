#include "gatt_svr.h"
#include "common_types.h"
#include "stepper_motor.h"
#include "esp_log.h"
#include "host/ble_hs.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
#include "services/ans/ble_svc_ans.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "GATT_SVR";

// Static motor instance reference
static stepper_motor_t *g_motor = NULL;

// LED states
static uint8_t led_states[4] = {0, 0, 0, 0};

// Characteristic handles
static uint16_t led_handles[4];
static uint16_t motor_position_handle;
static uint16_t motor_command_handle;
static uint16_t motor_status_handle;
static uint16_t motor_speed_handle;

// Service UUIDs
static const ble_uuid128_t led_svc_uuid =
    BLE_UUID128_INIT(0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef);

static const ble_uuid128_t motor_svc_uuid =
    BLE_UUID128_INIT(0x87, 0x65, 0x43, 0x21, 0xab, 0xcd, 0xef, 0x90,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef);

// LED Characteristic UUIDs
static const ble_uuid128_t led_chr_uuids[4] = {
    BLE_UUID128_INIT(0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x01),
    BLE_UUID128_INIT(0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x02),
    BLE_UUID128_INIT(0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x03),
    BLE_UUID128_INIT(0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x04)
};

// Motor Characteristic UUIDs
static const ble_uuid128_t motor_position_chr_uuid =
    BLE_UUID128_INIT(0x87, 0x65, 0x43, 0x21, 0xab, 0xcd, 0xef, 0x90,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x01);

static const ble_uuid128_t motor_command_chr_uuid =
    BLE_UUID128_INIT(0x87, 0x65, 0x43, 0x21, 0xab, 0xcd, 0xef, 0x90,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x02);

static const ble_uuid128_t motor_status_chr_uuid =
    BLE_UUID128_INIT(0x87, 0x65, 0x43, 0x21, 0xab, 0xcd, 0xef, 0x90,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x03);

static const ble_uuid128_t motor_speed_chr_uuid =
    BLE_UUID128_INIT(0x87, 0x65, 0x43, 0x21, 0xab, 0xcd, 0xef, 0x90,
                     0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0x04);

// GPIO pin mappings
static const gpio_num_t led_gpios[4] = {
    DEFAULT_LED1_GPIO, DEFAULT_LED2_GPIO, DEFAULT_LED3_GPIO, DEFAULT_LED4_GPIO
};

// Forward declarations
static int gatt_svr_write(struct os_mbuf *om, uint16_t min_len, uint16_t max_len, void *dst, uint16_t *len);
static int led_svc_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
static int motor_svc_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);

// Initialize LED GPIOs
static esp_err_t led_gpio_init(void) {
    gpio_config_t io_conf = {0};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << DEFAULT_LED1_GPIO) | (1ULL << DEFAULT_LED2_GPIO) | 
                           (1ULL << DEFAULT_LED3_GPIO) | (1ULL << DEFAULT_LED4_GPIO);
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 0;
    
    esp_err_t ret = gpio_config(&io_conf);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to configure LED GPIOs");
        return ret;
    }
    
    // Turn off all LEDs initially
    for (int i = 0; i < 4; i++) {
        gpio_set_level(led_gpios[i], 0);
        led_states[i] = 0;
    }
    
    ESP_LOGI(TAG, "LED GPIOs initialized");
    return ESP_OK;
}

// Control LED based on index and state
static void led_control(int led_index, uint8_t state) {
    if (led_index >= 0 && led_index < 4) {
        gpio_set_level(led_gpios[led_index], state);
        led_states[led_index] = state;
        ESP_LOGI(TAG, "LED%d set to %d", led_index + 1, state);
    }
}

// Flash LED for command indication
static void flash_led(int led_index, int duration_ms) {
    if (led_index >= 0 && led_index < 4) {
        gpio_set_level(led_gpios[led_index], 1);
        vTaskDelay(pdMS_TO_TICKS(duration_ms));
        gpio_set_level(led_gpios[led_index], led_states[led_index]); // Restore previous state
    }
}

// Write helper function
static int gatt_svr_write(struct os_mbuf *om, uint16_t min_len, uint16_t max_len, void *dst, uint16_t *len) {
    uint16_t om_len = OS_MBUF_PKTLEN(om);
    
    if (om_len < min_len || om_len > max_len) {
        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
    }
    
    int rc = ble_hs_mbuf_to_flat(om, dst, max_len, len);
    if (rc != 0) {
        return BLE_ATT_ERR_UNLIKELY;
    }
    
    return 0;
}

// LED service access callback
static int led_svc_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg) {
    int led_index = -1;
    
    // Find which LED this handle corresponds to
    for (int i = 0; i < 4; i++) {
        if (attr_handle == led_handles[i]) {
            led_index = i;
            break;
        }
    }
    
    if (led_index == -1) {
        return BLE_ATT_ERR_UNLIKELY;
    }
    
    switch (ctxt->op) {
        case BLE_GATT_ACCESS_OP_READ_CHR:
            ESP_LOGI(TAG, "LED%d read; conn_handle=%d", led_index + 1, conn_handle);
            return os_mbuf_append(ctxt->om, &led_states[led_index], sizeof(uint8_t));
            
        case BLE_GATT_ACCESS_OP_WRITE_CHR:
            ESP_LOGI(TAG, "LED%d write; conn_handle=%d", led_index + 1, conn_handle);
            uint8_t new_state;
            int rc = gatt_svr_write(ctxt->om, sizeof(uint8_t), sizeof(uint8_t), &new_state, NULL);
            if (rc == 0) {
                led_control(led_index, new_state);
            }
            return rc;
            
        default:
            return BLE_ATT_ERR_UNLIKELY;
    }
}

// Motor service access callback
static int motor_svc_access(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg) {
    if (g_motor == NULL) {
        ESP_LOGE(TAG, "Motor instance not set");
        return BLE_ATT_ERR_UNLIKELY;
    }
    
    // Flash LED to indicate motor BLE activity
    flash_led(0, 50); // Quick flash LED1
    
    if (attr_handle == motor_position_handle) {
        switch (ctxt->op) {
            case BLE_GATT_ACCESS_OP_READ_CHR: {
                ESP_LOGI(TAG, "Motor position read; conn_handle=%d", conn_handle);
                int16_t position = stepper_motor_get_position(g_motor);
                return os_mbuf_append(ctxt->om, &position, sizeof(int16_t));
            }
            case BLE_GATT_ACCESS_OP_WRITE_CHR: {
                ESP_LOGI(TAG, "Motor position write; conn_handle=%d", conn_handle);
                int16_t new_position;
                int rc = gatt_svr_write(ctxt->om, sizeof(int16_t), sizeof(int16_t), &new_position, NULL);
                if (rc == 0) {
                    flash_led(0, 200); // Flash LED1 for position command
                    stepper_motor_move_to_position(g_motor, new_position);
                }
                return rc;
            }
        }
    } else if (attr_handle == motor_command_handle) {
        if (ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
            ESP_LOGI(TAG, "Motor command write; conn_handle=%d", conn_handle);
            
            uint8_t cmd_data[3];
            int rc = gatt_svr_write(ctxt->om, 3, 3, cmd_data, NULL);
            if (rc == 0) {
                uint8_t command = cmd_data[0];
                int16_t parameter = (cmd_data[2] << 8) | cmd_data[1]; // Little endian
                
                switch (command) {
                    case MOTOR_CMD_STOP:
                        flash_led(3, 100); // LED4 for stop
                        stepper_motor_stop(g_motor);
                        break;
                    case MOTOR_CMD_MOVE_ABSOLUTE:
                        flash_led(0, 200); // LED1 for absolute move
                        stepper_motor_move_to_position(g_motor, parameter);
                        break;
                    case MOTOR_CMD_MOVE_RELATIVE:
                        flash_led(1, 200); // LED2 for relative move
                        stepper_motor_move_relative(g_motor, parameter);
                        break;
                    case MOTOR_CMD_HOME:
                        flash_led(2, 500); // LED3 for home
                        stepper_motor_home(g_motor);
                        break;
                    case MOTOR_CMD_SET_SPEED:
                        flash_led(0, 100); // Double flash for speed
                        vTaskDelay(pdMS_TO_TICKS(50));
                        flash_led(0, 100);
                        stepper_motor_set_speed(g_motor, (uint16_t)parameter);
                        break;
                    case MOTOR_CMD_ENABLE:
                        led_control(1, 1); // LED2 solid on for enable
                        stepper_motor_enable(g_motor);
                        break;
                    case MOTOR_CMD_DISABLE:
                        led_control(1, 0); // LED2 off for disable
                        stepper_motor_disable(g_motor);
                        break;
                    default:
                        ESP_LOGW(TAG, "Unknown motor command: %d", command);
                        return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
                }
            }
            return rc;
        }
    } else if (attr_handle == motor_status_handle) {
        if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
            ESP_LOGI(TAG, "Motor status read; conn_handle=%d", conn_handle);
            
            uint8_t status_data[4];
            status_data[0] = (uint8_t)stepper_motor_get_status(g_motor);
            int16_t pos = stepper_motor_get_position(g_motor);
            status_data[1] = pos & 0xFF;
            status_data[2] = (pos >> 8) & 0xFF;
            status_data[3] = stepper_motor_is_fault(g_motor) ? 1 : 0;
            
            return os_mbuf_append(ctxt->om, status_data, sizeof(status_data));
        }
    } else if (attr_handle == motor_speed_handle) {
        switch (ctxt->op) {
            case BLE_GATT_ACCESS_OP_READ_CHR: {
                ESP_LOGI(TAG, "Motor speed read; conn_handle=%d", conn_handle);
                uint16_t speed = g_motor->speed_delay_ms;
                return os_mbuf_append(ctxt->om, &speed, sizeof(uint16_t));
            }
            case BLE_GATT_ACCESS_OP_WRITE_CHR: {
                ESP_LOGI(TAG, "Motor speed write; conn_handle=%d", conn_handle);
                uint16_t new_speed;
                int rc = gatt_svr_write(ctxt->om, sizeof(uint16_t), sizeof(uint16_t), &new_speed, NULL);
                if (rc == 0) {
                    flash_led(0, 100);
                    vTaskDelay(pdMS_TO_TICKS(50));
                    flash_led(0, 100);
                    stepper_motor_set_speed(g_motor, new_speed);
                }
                return rc;
            }
        }
    }
    
    return BLE_ATT_ERR_UNLIKELY;
}

// GATT service definitions
static const struct ble_gatt_svc_def gatt_svr_svcs[] = {
    {
        // LED Control Service
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &led_svc_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &led_chr_uuids[0].u,
                .access_cb = led_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE,
                .val_handle = &led_handles[0],
            }, {
                .uuid = &led_chr_uuids[1].u,
                .access_cb = led_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE,
                .val_handle = &led_handles[1],
            }, {
                .uuid = &led_chr_uuids[2].u,
                .access_cb = led_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE,
                .val_handle = &led_handles[2],
            }, {
                .uuid = &led_chr_uuids[3].u,
                .access_cb = led_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE,
                .val_handle = &led_handles[3],
            }, {
                0, // End of characteristics
            }
        },
    },
    {
        // Motor Control Service
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &motor_svc_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &motor_position_chr_uuid.u,
                .access_cb = motor_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &motor_position_handle,
            }, {
                .uuid = &motor_command_chr_uuid.u,
                .access_cb = motor_svc_access,
                .flags = BLE_GATT_CHR_F_WRITE,
                .val_handle = &motor_command_handle,
            }, {
                .uuid = &motor_status_chr_uuid.u,
                .access_cb = motor_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &motor_status_handle,
            }, {
                .uuid = &motor_speed_chr_uuid.u,
                .access_cb = motor_svc_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE,
                .val_handle = &motor_speed_handle,
            }, {
                0, // End of characteristics
            }
        },
    },
    {
        0, // End of services
    },
};

void gatt_svr_register_cb(struct ble_gatt_register_ctxt *ctxt, void *arg) {
    char buf[BLE_UUID_STR_LEN];
    
    switch (ctxt->op) {
        case BLE_GATT_REGISTER_OP_SVC:
            ESP_LOGI(TAG, "Registered service %s with handle=%d",
                    ble_uuid_to_str(ctxt->svc.svc_def->uuid, buf),
                    ctxt->svc.handle);
            break;
            
        case BLE_GATT_REGISTER_OP_CHR:
            ESP_LOGI(TAG, "Registered characteristic %s with def_handle=%d val_handle=%d",
                    ble_uuid_to_str(ctxt->chr.chr_def->uuid, buf),
                    ctxt->chr.def_handle,
                    ctxt->chr.val_handle);
            break;
            
        case BLE_GATT_REGISTER_OP_DSC:
            ESP_LOGI(TAG, "Registered descriptor %s with handle=%d",
                    ble_uuid_to_str(ctxt->dsc.dsc_def->uuid, buf),
                    ctxt->dsc.handle);
            break;
            
        default:
            break;
    }
}

void gatt_svr_set_motor(void *motor) {
    g_motor = (stepper_motor_t *)motor;
    ESP_LOGI(TAG, "Motor instance set for GATT server");
}

esp_err_t gatt_svr_init(void) {
    esp_err_t ret;
    
    // Initialize LED GPIOs
    ret = led_gpio_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize LED GPIOs");
        return ret;
    }
    
    // Initialize BLE services
    ble_svc_gap_init();
    ble_svc_gatt_init();
    ble_svc_ans_init();
    
    // Register GATT services
    int rc = ble_gatts_count_cfg(gatt_svr_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to count GATT configuration: %d", rc);
        return ESP_FAIL;
    }
    
    rc = ble_gatts_add_svcs(gatt_svr_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to add GATT services: %d", rc);
        return ESP_FAIL;
    }
    
    ESP_LOGI(TAG, "GATT server initialized successfully");
    return ESP_OK;
} 