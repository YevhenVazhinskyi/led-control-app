#include "ble_peripheral.h"
#include "gatt_svr.h"
#include "common_types.h"
#include "esp_log.h"
#include "esp_nimble_hci.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "BLE_PERIPHERAL";

// Connection handle
static uint16_t conn_handle = BLE_HS_CONN_HANDLE_NONE;
static bool is_connected = false;

// Advertising data
static uint8_t ble_addr_type;

// Event handlers
static int ble_gap_event(struct ble_gap_event *event, void *arg);
static void ble_advertise(void);

// Advertising callback
static int ble_gap_event(struct ble_gap_event *event, void *arg) {
    switch (event->type) {
        case BLE_GAP_EVENT_CONNECT:
            ESP_LOGI(TAG, "Connection %s; status=%d",
                    event->connect.status == 0 ? "established" : "failed",
                    event->connect.status);
                    
            if (event->connect.status == 0) {
                conn_handle = event->connect.conn_handle;
                is_connected = true;
                ESP_LOGI(TAG, "Connection handle: %d", conn_handle);
            } else {
                // Connection failed, restart advertising
                ble_advertise();
            }
            break;
            
        case BLE_GAP_EVENT_DISCONNECT:
            ESP_LOGI(TAG, "Disconnect; reason=%d", event->disconnect.reason);
            conn_handle = BLE_HS_CONN_HANDLE_NONE;
            is_connected = false;
            
            // Restart advertising
            ble_advertise();
            break;
            
        case BLE_GAP_EVENT_ADV_COMPLETE:
            ESP_LOGI(TAG, "Advertising complete; reason=%d", event->adv_complete.reason);
            ble_advertise();
            break;
            
        case BLE_GAP_EVENT_CONN_UPDATE:
            ESP_LOGI(TAG, "Connection updated; status=%d", event->conn_update.status);
            break;
            
        case BLE_GAP_EVENT_SUBSCRIBE:
            ESP_LOGI(TAG, "Subscribe event; conn_handle=%d attr_handle=%d "
                         "reason=%d prevn=%d curn=%d previ=%d curi=%d",
                    event->subscribe.conn_handle,
                    event->subscribe.attr_handle,
                    event->subscribe.reason,
                    event->subscribe.prev_notify,
                    event->subscribe.cur_notify,
                    event->subscribe.prev_indicate,
                    event->subscribe.cur_indicate);
            break;
            
        case BLE_GAP_EVENT_MTU:
            ESP_LOGI(TAG, "MTU update event; conn_handle=%d cid=%d mtu=%d",
                    event->mtu.conn_handle,
                    event->mtu.channel_id,
                    event->mtu.value);
            break;
            
        default:
            ESP_LOGD(TAG, "Unhandled GAP event: %d", event->type);
            break;
    }
    
    return 0;
}

// Start advertising
static void ble_advertise(void) {
    struct ble_gap_adv_params adv_params;
    struct ble_hs_adv_fields fields;
    int rc;
    
    // Configure advertising parameters
    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;
    adv_params.itvl_min = BLE_ADV_INTERVAL_MIN;
    adv_params.itvl_max = BLE_ADV_INTERVAL_MAX;
    
    // Configure advertising data
    memset(&fields, 0, sizeof(fields));
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.tx_pwr_lvl_is_present = 1;
    fields.tx_pwr_lvl = BLE_HS_ADV_TX_PWR_LVL_AUTO;
    fields.name = (uint8_t *)BLE_DEVICE_NAME;
    fields.name_len = strlen(BLE_DEVICE_NAME);
    fields.name_is_complete = 1;
    
    rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "Error setting advertisement data; rc=%d", rc);
        return;
    }
    
    // Start advertising
    rc = ble_gap_adv_start(ble_addr_type, NULL, BLE_HS_FOREVER,
                          &adv_params, ble_gap_event, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "Error enabling advertisement; rc=%d", rc);
        return;
    }
    
    ESP_LOGI(TAG, "Advertising started");
}

// BLE stack reset callback
static void ble_on_reset(int reason) {
    ESP_LOGE(TAG, "BLE stack reset: %d", reason);
}

// BLE stack sync callback
static void ble_on_sync(void) {
    int rc;
    
    // Determine the best address type
    rc = ble_hs_util_ensure_addr(0);
    if (rc != 0) {
        ESP_LOGE(TAG, "Error determining address type; rc=%d", rc);
        return;
    }
    
    // Figure out address to use
    rc = ble_hs_id_infer_auto(0, &ble_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "Error inferring address type; rc=%d", rc);
        return;
    }
    
    // Print device address
    uint8_t addr_val[6] = {0};
    rc = ble_hs_id_copy_addr(ble_addr_type, addr_val, NULL);
    if (rc == 0) {
        ESP_LOGI(TAG, "Device Address: %02x:%02x:%02x:%02x:%02x:%02x",
                addr_val[5], addr_val[4], addr_val[3],
                addr_val[2], addr_val[1], addr_val[0]);
    }
    
    // Start advertising
    ble_advertise();
}

// BLE host task
static void ble_host_task(void *param) {
    ESP_LOGI(TAG, "BLE Host Task Started");
    
    // This function will return only when nimble_port_stop() is executed
    nimble_port_run();
    
    nimble_port_freertos_deinit();
}

esp_err_t ble_peripheral_init(void) {
    esp_err_t ret;
    
    ESP_LOGI(TAG, "Initializing BLE peripheral");
    
    // Initialize NVS for BLE stack
    ret = nimble_port_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to init nimble: %s", esp_err_to_name(ret));
        return ret;
    }
    
    // Configure the host stack
    ble_hs_cfg.reset_cb = ble_on_reset;
    ble_hs_cfg.sync_cb = ble_on_sync;
    ble_hs_cfg.gatts_register_cb = gatt_svr_register_cb;
    ble_hs_cfg.store_status_cb = ble_store_util_status_rr;
    
    // Set device name
    ble_svc_gap_device_name_set(BLE_DEVICE_NAME);
    ble_svc_gap_appearance_set(BLE_APPEARANCE);
    
    // Initialize GATT server
    ret = gatt_svr_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize GATT server");
        return ret;
    }
    
    // Start the FreeRTOS task for BLE host
    nimble_port_freertos_init(ble_host_task);
    
    ESP_LOGI(TAG, "BLE peripheral initialized successfully");
    return ESP_OK;
}

esp_err_t ble_peripheral_start_advertising(void) {
    if (is_connected) {
        ESP_LOGW(TAG, "Already connected, cannot start advertising");
        return ESP_ERR_INVALID_STATE;
    }
    
    ble_advertise();
    return ESP_OK;
}

esp_err_t ble_peripheral_stop_advertising(void) {
    int rc = ble_gap_adv_stop();
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to stop advertising: %d", rc);
        return ESP_FAIL;
    }
    
    ESP_LOGI(TAG, "Advertising stopped");
    return ESP_OK;
}

bool ble_peripheral_is_connected(void) {
    return is_connected;
}

uint16_t ble_peripheral_get_conn_handle(void) {
    return conn_handle;
} 