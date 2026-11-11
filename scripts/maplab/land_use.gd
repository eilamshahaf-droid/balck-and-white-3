class_name LandUse
extends RefCounted
## What a block of the map is used for. Names and colours live in MapLabSettings,
## in this order.

enum Use { HOMES, OFFICES, INDUSTRY, PUBLIC, PARK, SQUARE }

## A block too thin to build on, left as pavement.
const PAVEMENT := -1
