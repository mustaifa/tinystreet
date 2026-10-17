# Midnight Ledger: SOLUTIONS (spoilers)

**Spoiler warning.** Reference solutions for every page, found by the solver and replayed through the game rules. Many pages have other valid solutions; these are not the only answers.

Crates are numbered left to right, tickets 1 and 2. Ringing a ticket's bell is a move.

## e01: One Bell (bell_timing)

The first coffee has nowhere to go but the counter, which has one space. Ring Mr. Basil's ticket before the tea comes off the crate: his order completes, Theo arrives and takes the waiting coffee, and the counter is free again. Give that tea to Mira instead and the coffee is stuck on the counter.

1. crate 1: coffee -> counter
2. ring ticket 2
3. crate 1: tea -> ticket 2 [serves Mr. Basil] [serves Theo]
4. crate 1: croissant -> ticket 1
5. crate 2: coffee -> ticket 2 [serves Omar]
6. crate 2: tea -> ticket 1
7. crate 2: croissant -> ticket 1 [serves Mira]

## e02: The Last Shall Be First (backward)

Theo only arrives after Ada and Mira, all through ticket 1, so ticket 1 does all the work while Mr. Basil waits. The search proves that every move feeding his ticket before Theo is served leads to a dead end. His croissant and cupcake can wait in the right crate until the end.

1. crate 1: cupcake -> ticket 1
2. crate 1: coffee -> ticket 1
3. crate 1: coffee -> ticket 1 [serves Ada]
4. crate 2: croissant -> ticket 1 [serves Mira]
5. crate 2: coffee -> ticket 1 [serves Theo]
6. crate 3: cupcake -> ticket 2
7. crate 3: croissant -> ticket 2 [serves Mr. Basil]

## e03: The Precise Hand (precision)

There are 8 items, so every solution taps exactly 8 times. The search proved that no solution uses zero rings, so 9 moves is the true minimum. Ring Omar's ticket when both tickets want tea: his order completes, Theo arrives and takes the coffee you parked, and Lena's order follows.

1. crate 2: tea -> ticket 1 [serves Ada]
2. crate 1: coffee -> counter
3. ring ticket 2
4. crate 1: tea -> ticket 2 [serves Omar] [serves Theo]
5. crate 1: coffee -> ticket 2
6. crate 1: tea -> ticket 1
7. crate 2: coffee -> ticket 2
8. crate 2: coffee -> ticket 2 [serves Lena]
9. crate 2: tea -> ticket 1 [serves Mr. Basil]

## e04: One Empty Chair (empty_space)

With one counter space, only the middle crate's coffee can be parked: it is the single item between Mira and her tea. The search proves that parking any other coffee first is a dead end. Theo then arrives and drinks the parked coffee, freeing the space for the next squeeze, and Ada is served last as the ledger asks.

1. crate 2: croissant -> ticket 1
2. crate 2: coffee -> counter
3. crate 2: tea -> ticket 1 [serves Mira] [serves Theo]
4. crate 1: coffee -> ticket 1
5. crate 1: coffee -> counter
6. crate 1: tea -> ticket 1
7. crate 1: croissant -> ticket 1 [serves Mr. Basil]
8. crate 3: coffee -> ticket 1
9. crate 3: coffee -> ticket 1 [serves Omar]
10. crate 3: croissant -> ticket 2 [serves Ada]

## e05: Patience (delay_completion)

Serving Theo early is the trap: Lena would arrive in his ticket while Mira still needs croissants, and the search proves every such line fails. Serve Mira first (park a cupcake on the counter to reach her second croissant), then let Theo go. Mr. Basil arrives in his place, and Lena and Basil follow in the ledger's order.

1. crate 3: croissant -> ticket 1
2. crate 2: cupcake -> counter
3. crate 2: croissant -> ticket 1 [serves Mira]
4. crate 1: coffee -> ticket 2 [serves Theo]
5. crate 1: coffee -> ticket 2
6. crate 1: croissant -> ticket 1
7. crate 3: coffee -> ticket 2
8. crate 3: cupcake -> ticket 1 [serves Lena]
9. crate 2: croissant -> ticket 2 [serves Mr. Basil]

## e06: Last Orders (backward)

Mr. Basil is served last, so his final cupcake must be the one still reachable at the end: the one under the coffee in the right crate. The left crate's cupcakes go to ticket 1 instead: Rosa takes one, Theo the other. Feeding Mr. Basil early, or spending the right crate's cupcake on Rosa, are both proven dead ends.

1. crate 2: croissant -> ticket 1
2. crate 2: croissant -> ticket 2
3. crate 2: coffee -> ticket 1
4. crate 3: coffee -> ticket 1 [serves Omar]
5. crate 1: cupcake -> ticket 1 [serves Rosa]
6. crate 1: cupcake -> ticket 1
7. crate 1: coffee -> ticket 1 [serves Theo]
8. crate 3: cupcake -> ticket 2 [serves Mr. Basil]

## e07: The Quiet Bell (ring_late)

Put everything Mira needs on the counter first (her croissant and a tea), then ring Rosa's ticket. The next cupcake finishes Rosa, Mira takes her place and is served instantly from the counter, and only then does Pim get his cupcake. On this route, ringing ticket 1 at any point is a proven dead end.

1. crate 1: cupcake -> ticket 2
2. crate 1: cupcake -> ticket 2
3. crate 1: tea -> ticket 1
4. crate 3: tea -> ticket 1
5. crate 3: tea -> ticket 1 [serves Mr. Basil]
6. crate 3: tea -> ticket 2 [serves Lena]
7. crate 2: croissant -> counter
8. crate 2: tea -> counter
9. ring ticket 2
10. crate 1: cupcake -> ticket 2 [serves Rosa] [serves Mira]
11. crate 2: cupcake -> ticket 1 [serves Pim]

## e08: False Economy (local_good)

Ada's order looks harmless to finish, but her ticket is the door the queue comes through. Serve her before Theo and the queue moves too early; the search proves those lines fail. Serve Theo first (his coffee is on top of the middle crate), then finish Ada, and Omar and Mr. Basil arrive in the order the ledger wants.

1. crate 1: croissant -> ticket 1
2. crate 1: coffee -> ticket 1
3. crate 2: coffee -> ticket 2 [serves Theo]
4. crate 1: tea -> ticket 1 [serves Ada]
5. crate 1: coffee -> ticket 2
6. crate 2: croissant -> ticket 1
7. crate 3: tea -> ticket 1
8. crate 3: croissant -> ticket 2
9. crate 3: coffee -> ticket 2 [serves Omar]
10. crate 2: tea -> ticket 1 [serves Mr. Basil]

## e09: Three Bells (min_rings)

Every tea would go to Mr. Basil at ticket 1, but he must be served after Mira, the last to arrive. Three customers pass through ticket 2 (Lena, Ada and Mira), and each needs a fresh ring before their tea, because the bell stops when an order is served. The search proved that no solution uses fewer than three rings, so 11 moves is the minimum.

1. crate 2: cupcake -> ticket 1
2. crate 2: cupcake -> ticket 2
3. crate 2: cupcake -> counter
4. ring ticket 2
5. crate 1: tea -> ticket 2 [serves Lena]
6. crate 1: coffee -> ticket 1
7. ring ticket 2
8. crate 1: tea -> ticket 2 [serves Ada]
9. ring ticket 2
10. crate 1: tea -> ticket 2 [serves Mira]
11. crate 2: tea -> ticket 1 [serves Mr. Basil]

## e10: Hot Croissants (fresh)

Mira's last croissant should come from the hot right-hand crate, not the cold left one (the search proves the cold one is a dead end there). The cold croissants are worth more later, parked on the counter for Omar. Ring Lena's ticket so a cupcake finishes her order; Omar arrives, collects both parked croissants, takes his coffee, and only then does Pim get his hot cupcake.

1. crate 1: croissant -> ticket 1
2. crate 2: coffee -> ticket 1
3. crate 2: coffee -> ticket 2
4. crate 2: cupcake -> ticket 2
5. crate 3: croissant -> ticket 1 [serves Mira]
6. crate 2: coffee -> ticket 1
7. crate 3: croissant -> ticket 1
8. crate 1: croissant -> counter
9. crate 1: croissant -> counter
10. ring ticket 2
11. crate 3: cupcake -> ticket 2 [serves Lena]
12. crate 1: coffee -> ticket 2 [serves Omar]
13. crate 3: cupcake -> ticket 1 [serves Pim]

## e11: The Strapped Crate (lock)

Serve Theo and Mira first: that opens the strapped crate. Now Ada (ticket 1) and Lena (ticket 2) both want coffee, and Ada must wait for Mr. Basil, who only arrives when Lena leaves. Ring Lena's ticket, finish her order (parking a croissant for Mr. Basil), serve Basil, and give Ada her last coffee at the end.

1. crate 1: coffee -> ticket 1
2. crate 1: coffee -> ticket 1
3. crate 3: coffee -> ticket 1 [serves Theo]
4. crate 1: croissant -> ticket 1 [serves Mira]
5. ring ticket 2
6. crate 1: coffee -> ticket 2
7. crate 2: cupcake -> ticket 2
8. crate 2: croissant -> counter
9. crate 2: coffee -> ticket 2 [serves Lena]
10. crate 3: croissant -> ticket 2
11. crate 3: cupcake -> ticket 1
12. crate 3: cupcake -> ticket 2 [serves Mr. Basil]
13. crate 2: coffee -> ticket 1 [serves Ada]

## e12: Two Lessons (combine)

First, patience: give Theo his croissant before Omar leaves, because Mira takes Omar's ticket and must be served last. Then park the cupcake Rosa will need, let Theo go so Rosa arrives and collects it, and save the bell: when Rosa and Mira both want the final croissant, ring Rosa's ticket.

1. crate 1: cupcake -> ticket 1
2. crate 1: coffee -> ticket 1
3. crate 1: croissant -> ticket 2
4. crate 3: coffee -> ticket 1 [serves Omar]
5. crate 3: coffee -> ticket 2
6. crate 2: cupcake -> counter
7. crate 2: croissant -> ticket 1
8. crate 2: coffee -> ticket 2 [serves Theo]
9. crate 2: coffee -> ticket 2
10. ring ticket 2
11. crate 1: croissant -> ticket 2 [serves Rosa]
12. crate 3: croissant -> ticket 1 [serves Mira]

## e13: The Midnight Ledger (combine)

After Mira, Mr. Basil arrives in ticket 1 and would take every tea, but he must wait for Theo, who hasn't arrived. The single ring belongs to Lena right then: her teas and her two hot items go straight to her, her departure brings Theo, and the coffee you parked jumps to him. Park Omar's coffee too, give Basil exactly one tea, finish Theo, and then Basil and Omar fall into place.

1. crate 1: cupcake -> ticket 1
2. crate 1: tea -> ticket 1 [serves Mira]
3. ring ticket 2
4. crate 2: tea -> ticket 2
5. crate 2: coffee -> counter
6. crate 2: cupcake -> ticket 2
7. crate 2: tea -> ticket 2 [serves Lena]
8. crate 3: coffee -> counter
9. crate 3: tea -> ticket 1
10. crate 3: tea -> ticket 2 [serves Theo]
11. crate 1: cupcake -> ticket 1 [serves Mr. Basil]
12. crate 1: cupcake -> ticket 2
13. crate 3: cupcake -> ticket 2 [serves Omar]

