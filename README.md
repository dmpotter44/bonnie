bonnie
======

Clinical Quality Measure Testing Tool

delayed_job
-----------

In order to send emails in the background, bonnie uses [the delayed_job gem](https://github.com/collectiveidea/delayed_job). In order to run delayed_job, either use `scripts/delayed_job` or `rake jobs:work`. Emails will not be sent unless a `delayed_job` worker is running somewhere.
