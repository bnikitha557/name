package com.oms.ordermanagementsystem.repository;

import com.oms.ordermanagementsystem.model.Order;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrderRepository extends JpaRepository<Order, Long> {
}