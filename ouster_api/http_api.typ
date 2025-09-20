= HTTP API

== 简介

  Ouster激光雷达启动后运行了一个HTTP Server，连接至雷达的主机可以
  发起HTTP请求，获取雷达状态或对雷达进行配置，基本的HTTP请求方式
  包括GET、POST、PUT和DELETE，具体的API列表，参考固件用户手册。

== API验证

  实验使用的激光雷达型号为OS-1-64，固件版本号为v2.5.3，域名为
  “ouster”。以下使用`curl`命令行工具向雷达发起HTTP请求：

  + *GET*

    获取`sensor_info`：

    ```bash
    curl http://ouster/api/v1/sensor/metadata/sensor_info | jq
    ```

    返回结果：

    ```bash
    {
      "prod_pn": "840-103575-06",
      "build_date": "2024-01-11T06:02:47Z",
      "status": "STANDBY",
      "prod_sn": "122220003521",
      "prod_line": "OS-1-64-BH",
      "build_rev": "v2.5.3",
      "image_rev": "ousteros-image-prod-aries-v2.5.3+20240111055903",
      "initialization_id": 7109744
    }
    ```

  + *POST*

    `POST`方法可用于配置雷达：

    ```bash
    curl -X POST http://ouster/api/v1/sensor/config -H 'Content-Type: application/json' --data-raw '{"lidar_mode": "1024x10"}'
    ```

    验证配置结果，可以使用：

    ```bash
    curl http://ouster/api/v1/sensor/config
    ```
    
  + *PUT*

    实验使用的激光雷达具有用户数据域(user data field)用于写入用户数据：

    ```bash
    curl -X PUT http://ouster/api/v1/user/data -H 'Content-Type: application/json' -d '"my own data"'
    ```

    验证结果：

    ```bash
    curl http://ouster/api/v1/user/data
    ```

    返回`"my own data"`。

  + *DELETE*

    用户数据域的内容可以擦除：

    ```bash
    curl -X DELETE http://ouster/api/v1/user/data
    ```

    验证结果：

    ```bash
    curl http://ouster/api/v1/user/data
    ```

    返回`""`。

== 通过libcurl使用HTTP API

  libcurl是一个功能强大、跨平台的开源网络传输库，支持多种常见的网络协议，
  包括HTTP。此处使用C和libcurl提供的C API编程实现使用HTTP API相关的操作。

  + *curl client初始化和释放*

    使用libcurl的easy interface之前，先获取一个easy handle：

    ```c
    CURL *os_init_curl_client()
    {
        curl_global_init(CURL_GLOBAL_DEFAULT);
        return curl_easy_init();
    }
    ```

    使用libcurl结束后，调用以下的函数执行释放：

    ```c
    void os_deinit_curl_client(CURL *curl)
    {
        curl_easy_cleanup(curl);
        curl_global_cleanup();
    }
    ```

  + *GET*

    以下这段代码的作用是：发送一个HTTP GET请求，并将服务器响应完整地
    存储到内存中，供后续处理:

    ```c
    // 用于保存服务器返回的响应数据
    struct memory{
        char *response; // 指向动态分配的内存，用来存放返回的内容
        size_t size;  // 记录当前已存储的字节数
    };
    
    // 回调函数, 当libcurl收到数据时会调用该函数
    static size_t write_callback(void *buffer, size_t size, size_t nmemb, void *userp)
    {
        // 计算数据大小
        size_t realsize = size * nmemb;
        struct memory *mem = (struct memory *)userp;
        // 扩展内存
        char *p = realloc(mem->response, mem->size + realsize + 1);
        if(!p) return 0;
        // 将新数据追加到已有的response中
        mem->response = p;
        memcpy(&(mem->response[mem->size]), buffer, realsize);
        mem->size += realsize;
        // 在最后加上字符串结束符'\0'，保证内容可作为C字符串使用
        mem->response[mem->size] = '\0';
        return realsize;
    }
    
    CURLcode os_curl_get(CURL *curl, char *url, struct memory *mem)
    {
        curl_easy_reset(curl);
        // 设置请求的URL
        curl_easy_setopt(curl, CURLOPT_URL, url);
        // 设置写回调函数和用户数据，以便接收服务器响应
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)mem);
        // 设置请求方式为 HTTP GET
        curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
        // 执行请求，并返回结果
        return curl_easy_perform(curl);
    }
    ```

  + *POST*

    以下函数通过`libcurl`向指定的URL发送一个带有JSON数据的
    HTTP POST请求，常用于配置Ouster激光雷达或向其发送控制命令:

    ```c
    CURLcode os_curl_post(CURL *curl, char *url, char *str)
    {
        curl_easy_reset(curl);
        // 设置目标URL
        curl_easy_setopt(curl, CURLOPT_URL, url);
        // 添加HTTP请求头, 指定请求体为JSON格式
        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, str);
        CURLcode res;
        // 执行POST请求
        res = curl_easy_perform(curl);
        // 释放之前创建的请求头链表
        curl_slist_free_all(headers);
        return res;
    }
    ```

  + *PUT*

    以下函数实现了HTTP PUT请求，与前面的POST实现很相似，只是
    把请求方法改成了PUT：

    ```c
    CURLcode os_curl_put(CURL *curl, char *url, char *str)
    {
        curl_easy_reset(curl);
        curl_easy_setopt(curl, CURLOPT_URL, url);
        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, str);
        CURLcode res;
        res = curl_easy_perform(curl);
        curl_slist_free_all(headers);
        return res;
    }
    ```

  + *DELETE*

    以下函数向指定URL发送一个HTTP DELETE请求，用于删除或关闭雷达中的某些配置或资源：
    
    ```c
    CURLcode os_curl_delete(CURL *curl, char *url)
    {
        curl_easy_reset(curl);
        curl_easy_setopt(curl, CURLOPT_URL, url);
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
        CURLcode res;
        res = curl_easy_perform(curl);
        return res;
    }
    ```

  下面对以上的函数进行简单验证，主要操作是：
  - 读取激光雷达配置；
  - 修改配置“lidar_mode”为“512x10”；
  - 再次读取配置以验证配置修改成功；
  - 读取用户数据域内容；
  - 用户数据域写入内容为“my own data”；
  - 再次读取用户数据域内容以验证写入成功；
  - 擦除用户数据域内容并重新读取以验证擦除结果。

  ```c
  // 使用GET方法获取用户数据域的内容
  static int get_user_data(CURL *curl)
  {
      int result;
      printf("Getting user data...\n");
      char *url = "http://ouster/api/v1/user/data";
      struct memory mem = {0};
      CURLcode res = os_curl_get(curl, url, &mem);
      if(res == CURLE_OK){
          printf("%s\n", mem.response);
          result = EXIT_SUCCESS;
      } else{
          perror("Error: get user data failed.");
          result = EXIT_FAILURE;
      }
      free(mem.response);
      return result;
  }
  
  // 使用PUT方法向用户数据域写入数据
  static int set_user_data(CURL *curl, char *str)
  {
      printf("Setting user data...\n");
      char *url = "http://ouster/api/v1/user/data";
      CURLcode res = os_curl_put(curl, url, str);
      if(res == CURLE_OK){
          printf("Set user data success.\n");
          return EXIT_SUCCESS;
      } else{
          perror("Error: set user data failed.");
          return EXIT_FAILURE;
      }
  }
  
  // 使用DELETE方法擦除用户数据域的内容
  static int delete_user_data(CURL *curl)
  {
      printf("Deleting user data...\n");
      char *url = "http://ouster/api/v1/user/data";
      CURLcode res = os_curl_delete(curl, url);
      if(res == CURLE_OK){
          printf("Delete user data success.\n");
          return EXIT_SUCCESS;
      } else{
          perror("Error: delete user data failed.");
          return EXIT_FAILURE;
      }
  }
  
  // 使用GET方法获取激光雷达配置
  static int get_sensor_config(CURL *curl)
  {
      int result;
      printf("Getting sensor config...\n");
      char *url = "http://ouster/api/v1/sensor/config";
      struct memory mem = {0};
      CURLcode res = os_curl_get(curl, url, &mem);
      if(res == CURLE_OK){
          printf("%s\n", mem.response);
          result = EXIT_SUCCESS;
      } else{
          perror("Error: get sensor config failed.");
          result = EXIT_FAILURE;
      }
      free(mem.response);
      return result;
  }
  
  // 使用POST方法修改激光雷达配置
  static int set_sensor_config(CURL *curl, char *str)
  {
      printf("Setting sensor config...\n");
      char *url = "http://ouster/api/v1/sensor/config";
      CURLcode res = os_curl_post(curl, url, str);
      if(res == CURLE_OK){
          printf("Set sensor config success.\n");
          return EXIT_SUCCESS;
      } else{
          perror("Error: set sensor config failed.");
          return EXIT_FAILURE;
      }
  }
  
  static int curl_client_test()
  {
      // curl client初始化，获取一个easy handle
      CURL *curl = os_init_curl_client();
      if(!curl){
          perror("Error: initiate curl client failed.");
          return EXIT_FAILURE;
      }
      do{
          if(get_sensor_config(curl) == EXIT_FAILURE) break;
          char *config_str = "{\"lidar_mode\" : \"512x10\"}";
          if(set_sensor_config(curl, config_str) == EXIT_FAILURE) break;
          if(get_sensor_config(curl) == EXIT_FAILURE) break;
          if(get_user_data(curl) == EXIT_FAILURE) break;
          char *user_data_str = "\"my own data\"";
          if(set_user_data(curl, user_data_str) == EXIT_FAILURE) break;
          if(get_user_data(curl) == EXIT_FAILURE) break;
          if(delete_user_data(curl) == EXIT_FAILURE) break;
          if(get_user_data(curl) == EXIT_FAILURE) break;
          os_deinit_curl_client(curl);
          return EXIT_SUCCESS;
      } while(0);
      // easy handle使用完成后要执行释放
      os_deinit_curl_client(curl);
      return EXIT_FAILURE;
  }
  ```

  以上测试程序的执行结果：

  ```bash
  Getting sensor config...
  {"udp_port_imu": 7503, "nmea_ignore_valid_char": 0, "nmea_baud_rate": "BAUD_9600", "udp_profile_imu": "LEGACY", "sync_pulse_out_angle": 360, "udp_dest": "192.168.1.7", "nmea_leap_seconds": 0, "timestamp_mode": "TIME_FROM_INTERNAL_OSC", "udp_port_lidar": 7502, "lidar_mode": "1024x10", "sync_pulse_out_pulse_width": 10, "phase_lock_offset": 0, "nmea_in_polarity": "ACTIVE_HIGH", "columns_per_packet": 16, "udp_profile_lidar": "RNG15_RFL8_NIR8", "signal_multiplier": 1, "phase_lock_enable": false, "sync_pulse_in_polarity": "ACTIVE_HIGH", "azimuth_window": [0, 360000], "multipurpose_io_mode": "OFF", "sync_pulse_out_frequency": 1, "operating_mode": "STANDBY", "sync_pulse_out_polarity": "ACTIVE_HIGH"}
  Setting sensor config...
  Set sensor config success.
  Getting sensor config...
  {"udp_port_imu": 7503, "nmea_ignore_valid_char": 0, "nmea_baud_rate": "BAUD_9600", "udp_profile_imu": "LEGACY", "sync_pulse_out_angle": 360, "udp_dest": "192.168.1.7", "nmea_leap_seconds": 0, "timestamp_mode": "TIME_FROM_INTERNAL_OSC", "udp_port_lidar": 7502, "lidar_mode": "512x10", "sync_pulse_out_pulse_width": 10, "phase_lock_offset": 0, "nmea_in_polarity": "ACTIVE_HIGH", "columns_per_packet": 16, "udp_profile_lidar": "RNG15_RFL8_NIR8", "signal_multiplier": 1, "phase_lock_enable": false, "sync_pulse_in_polarity": "ACTIVE_HIGH", "azimuth_window": [0, 360000], "multipurpose_io_mode": "OFF", "sync_pulse_out_frequency": 1, "operating_mode": "STANDBY", "sync_pulse_out_polarity": "ACTIVE_HIGH"}
  Getting user data...
  ""
  Setting user data...
  Set user data success.
  Getting user data...
  "my own data"
  Deleting user data...
  Delete user data success.
  Getting user data...
  ""
  ```

