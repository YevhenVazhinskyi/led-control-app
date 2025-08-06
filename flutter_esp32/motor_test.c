#include "motor_test.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "MOTOR_TEST";

esp_err_t motor_test_hardware(stepper_motor_t *motor) {
    ESP_LOGI(TAG, "Starting hardware test...");
    
    if (motor == NULL) {
        ESP_LOGE(TAG, "Motor instance is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    // Check fault pin
    if (stepper_motor_is_fault(motor)) {
        ESP_LOGE(TAG, "Motor fault detected during hardware test");
        return ESP_ERR_INVALID_STATE;
    }
    
    // Test enable/disable
    ESP_LOGI(TAG, "Testing enable/disable...");
    esp_err_t ret = stepper_motor_enable(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to enable motor");
        return ret;
    }
    
    vTaskDelay(pdMS_TO_TICKS(1000));
    
    ret = stepper_motor_disable(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to disable motor");
        return ret;
    }
    
    ret = stepper_motor_enable(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to re-enable motor");
        return ret;
    }
    
    ESP_LOGI(TAG, "Hardware test completed successfully");
    return ESP_OK;
}

esp_err_t motor_test_movement(stepper_motor_t *motor) {
    ESP_LOGI(TAG, "Starting movement test...");
    
    if (motor == NULL) {
        ESP_LOGE(TAG, "Motor instance is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    // Use the existing test movement function
    stepper_motor_test_movement(motor);
    
    ESP_LOGI(TAG, "Movement test completed");
    return ESP_OK;
}

esp_err_t motor_test_position_accuracy(stepper_motor_t *motor) {
    ESP_LOGI(TAG, "Starting position accuracy test...");
    
    if (motor == NULL) {
        ESP_LOGE(TAG, "Motor instance is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    // Home motor first
    ESP_LOGI(TAG, "Homing motor...");
    esp_err_t ret = stepper_motor_home(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to home motor");
        return ret;
    }
    
    // Wait for homing to complete
    vTaskDelay(pdMS_TO_TICKS(5000));
    
    // Test various positions
    int16_t test_positions[] = {100, 500, 1000, 250, 750, 0};
    size_t num_positions = sizeof(test_positions) / sizeof(test_positions[0]);
    
    for (size_t i = 0; i < num_positions; i++) {
        ESP_LOGI(TAG, "Moving to position: %d", test_positions[i]);
        
        ret = stepper_motor_move_to_position(motor, test_positions[i]);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "Failed to move to position %d", test_positions[i]);
            return ret;
        }
        
        // Wait for movement to complete
        vTaskDelay(pdMS_TO_TICKS(3000));
        
        // Check current position
        int16_t current_pos = stepper_motor_get_position(motor);
        ESP_LOGI(TAG, "Target: %d, Actual: %d", test_positions[i], current_pos);
        
        if (abs(current_pos - test_positions[i]) > 5) {  // Allow 5 step tolerance
            ESP_LOGW(TAG, "Position accuracy warning: difference is %d steps", 
                    abs(current_pos - test_positions[i]));
        }
    }
    
    ESP_LOGI(TAG, "Position accuracy test completed");
    return ESP_OK;
}

esp_err_t motor_test_speed_variations(stepper_motor_t *motor) {
    ESP_LOGI(TAG, "Starting speed variation test...");
    
    if (motor == NULL) {
        ESP_LOGE(TAG, "Motor instance is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    // Test different speeds (delay in ms between steps)
    uint16_t test_speeds[] = {5, 10, 20, 50, 100};
    size_t num_speeds = sizeof(test_speeds) / sizeof(test_speeds[0]);
    
    for (size_t i = 0; i < num_speeds; i++) {
        ESP_LOGI(TAG, "Testing speed: %d ms delay", test_speeds[i]);
        
        esp_err_t ret = stepper_motor_set_speed(motor, test_speeds[i]);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "Failed to set speed to %d", test_speeds[i]);
            return ret;
        }
        
        // Move relative 200 steps forward and back
        ret = stepper_motor_move_relative(motor, 200);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "Failed to move relative");
            return ret;
        }
        
        vTaskDelay(pdMS_TO_TICKS(3000)); // Wait for movement
        
        ret = stepper_motor_move_relative(motor, -200);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "Failed to move relative back");
            return ret;
        }
        
        vTaskDelay(pdMS_TO_TICKS(3000)); // Wait for movement
    }
    
    // Reset to default speed
    stepper_motor_set_speed(motor, 10);
    
    ESP_LOGI(TAG, "Speed variation test completed");
    return ESP_OK;
}

esp_err_t motor_test_suite(stepper_motor_t *motor) {
    ESP_LOGI(TAG, "Starting comprehensive motor test suite...");
    
    if (motor == NULL) {
        ESP_LOGE(TAG, "Motor instance is NULL");
        return ESP_ERR_INVALID_ARG;
    }
    
    esp_err_t ret;
    
    // Run all tests in sequence
    ESP_LOGI(TAG, "=== Test 1: Hardware Test ===");
    ret = motor_test_hardware(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Hardware test failed");
        return ret;
    }
    
    ESP_LOGI(TAG, "=== Test 2: Basic Movement Test ===");
    ret = motor_test_movement(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Movement test failed");
        return ret;
    }
    
    ESP_LOGI(TAG, "=== Test 3: Position Accuracy Test ===");
    ret = motor_test_position_accuracy(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Position accuracy test failed");
        return ret;
    }
    
    ESP_LOGI(TAG, "=== Test 4: Speed Variation Test ===");
    ret = motor_test_speed_variations(motor);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Speed variation test failed");
        return ret;
    }
    
    ESP_LOGI(TAG, "=== All tests completed successfully! ===");
    return ESP_OK;
} 