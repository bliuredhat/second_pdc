### Fixed incorrect message when re-running a failed job

While adding new builds to an advisory, a progress bar displays, alongside a
message stating which build is currently being fetched from Brew.  In order to
tolerate temporary network problems and timeouts, fetching from Brew is retried
a few times if problems occur.

Previously, the displayed message was only correct for the first attempt at
fetching the data from Brew; subsequent attempts would always display "Please
wait..." while the fetching was in progress.

This has been fixed. A descriptive message like below will be shown for every
attempt to fetch builds, even after a failure:

    Fetching (build id or nvr) for (product version name)...
