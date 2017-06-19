### Remove rhnqa_tps_delay setting

Previously, the step 'rhnqa_tps_delay' is the delay after stage push and
before RHNQA TPS, which aims to give some time for push to finish.

Pub side had enhanced the sync setting to regenerate RHN repos before
completing the push. So remove the TPS delay setting in ET side.
