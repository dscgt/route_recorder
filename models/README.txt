
This directory contains example JSON structures for records (record.json), models (model.json), and groups (group.json), which represent single documents under the Firebase collections _records_, _models_, and _groups_ respectively. These collection names may change. No other collections or subcollections are necessary at this moment.

Overall notes:
- all `checkoutTime`s and `checkinTime`s are Firebase timestamp types

Notes about model.json:
- the `type` field of objects under the `fields` array can take the following values: "string", "number", and "select"
    - if the above field is set to "select", then a `groupId` must be provided
    - the same applies to the `type` field under `stopData.fields`
- a stop can exclude fields by putting field titles under its `exclude` array.
    - a better option in the future might be have fields specifying stops instead of the other way around.
- `groupId` within `fields`'s objects is a Firebase reference type

Notes about record.json:
- the `properties` field's key-value pairs are the fields defined by the record's respective model. The key-value pairs of `properties` under objects of the `stops` array are defined by the stop's respective model within the parent model.
- `modelId` is a Firebase reference type
