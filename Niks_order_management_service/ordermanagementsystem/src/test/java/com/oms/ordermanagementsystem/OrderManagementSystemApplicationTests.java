package com.oms.ordermanagementsystem;

import com.oms.ordermanagementsystem.client.AuthClient;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

@SpringBootTest
class OrderManagementSystemApplicationTests {

    @MockBean
    private AuthClient authClient;

    @Test
    void contextLoads() {
    }

}
