/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * Rx extensions.
 * Copyright 2023 AMRC
 */

import rx from "rxjs";

export const rxx = {
    flatten: () => rx.mergeMap(v => rx.from(v)),
};
