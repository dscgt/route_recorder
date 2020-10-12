
This directory contains example JSON structures for records (record.json), in-progress records (record_in_progress.json), models (model.json), and groups (group.json), which represent single documents under the Firebase collections `route_records`, `route_records_in_progress`, `route_models`, and `route_groups` respectively. This directory should be kept updated whenever structures and/or collection names change. These JSON files serve just as references; they are not used programmatically.

Overall notes:
- all time-related fields (`startTime`, `endTime`, `saveTime`) Firebase timestamp types

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
- `saves` describes how stops are separated by route save. For example, if a crewmember does stops a, b, and c on one day, and then saves it, and then he/she (or another crewmember) does stops d and e on another day, `saves` will express this. `saveTime` describes the time of saving. If a route did not need to be saved for resumption later (most routes will fall under this), `saves` will have only one entry

Notes about record_in_progress.json:
- the "record" property's value takes the structure of record.json's object
- the "model" property's value takes the structure of model.json's object
   - while it may be tempting, this should not be changed to be of a Firebase reference type for pointing to documents under the `models` collection, in order to avoid inconsistencies when a model changes while records utilizing that model are in progress
