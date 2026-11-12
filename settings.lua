data:extend({
  {
    type = "int-setting",
    name = "wp-factory-cart-battery-mj",
    setting_type = "startup",
    default_value = 10,
    minimum_value = 10,
    maximum_value = 50,
    order = "a",
  },
  {
    type = "double-setting",
    name = "wp-factory-cart-charge-mw",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 5,
    order = "b",
  },
  {
    type = "int-setting",
    name = "wp-factory-cart-cargo-slots",
    setting_type = "startup",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 50,
    order = "c",
  },
})
