#!/bin/sh

openclaw gateway call config.schema --json | jq '
  .schema
  | .properties = ((.properties // {}) + {
      "$schema": {
        "type": "string"
      }
    })
' > ./openclaw.schema.json
