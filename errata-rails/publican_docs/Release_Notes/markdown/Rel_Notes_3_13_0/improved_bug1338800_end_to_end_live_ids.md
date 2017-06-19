### Use year offset for end to end test advisory live ids

In order to support automatic end to end testing of Errata Tool,
the live ids assigned to end to end test advisories will use a
year offset. This avoids gaps in the sequence of ids assigned to
genuine advisories, and also makes it easier to identify test
advisories.
