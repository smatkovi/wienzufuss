# Die Schnittstelle hinter „Wien zu Fuß"

Abgelesen aus der Android-App `com.digitalsunray.wienzufuss` 3.3.3
(Retrofit-Schnittstelle `core/remote/i`, Modelle unter `core/model`,
Gson-Adapter `p4/*`). Was hier als Antwortform steht, kommt aus den
Modellklassen, nicht aus mitgeschnittenen Antworten — der Dienst reicht das
JSON deshalb unverändert durch und die Oberfläche liest es nachsichtig.

## Anmeldung (Firebase)

Projekt `wien-zu-fuss---live`, API-Schlüssel aus der APK (Ressource
`google_api_key`):

    AIzaSyDvYwJ8djFcaiKSgpyICAOXRdBE8tU8lsI

Der Schlüssel ist **nicht** auf Android-Apps beschränkt (`GET
identitytoolkit.googleapis.com/v1/projects?key=…` antwortet ohne
`X-Android-*`-Köpfe), und reCAPTCHA ist für E-Mail/Passwort nicht
erzwungen (`v2/recaptchaConfig` → `ENFORCEMENT_STATE_UNSPECIFIED`). Damit
geht die Anmeldung über die REST-Schnittstelle von Firebase:

| Zweck | Aufruf |
|---|---|
| Anmelden | `POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=…` `{email, password, returnSecureToken:true}` → `{idToken, refreshToken, expiresIn, localId, email}` |
| Registrieren | `POST …/v1/accounts:signUp?key=…` `{email, password, returnSecureToken:true}` |
| Token erneuern | `POST https://securetoken.googleapis.com/v1/token?key=…` (Form) `grant_type=refresh_token&refresh_token=…` → `{id_token, refresh_token, expires_in, user_id}` |

Fehler kommen als `{"error":{"code":400,"message":"INVALID_LOGIN_CREDENTIALS"}}`
und Ähnliches (`EMAIL_EXISTS`, `WEAK_PASSWORD : …`, `TOO_MANY_ATTEMPTS_TRY_LATER`,
`USER_DISABLED`, `TOKEN_EXPIRED`, `INVALID_REFRESH_TOKEN`).

Google- und Facebook-Anmeldung der Android-App laufen über deren SDKs
(`signInWithIdp`); ohne Browser-OAuth nicht nachzubauen.

## Backend

Basis `https://wzfapp.wienzufuss.at/api/`. Einziger Kopf, den die App
mitschickt: `Authorization: Bearer <Firebase-ID-Token>` (OkHttp-Interceptor
`core/remote/interceptor/a`). Ohne Token: HTTP 401. Kein App Check, keine
Play Integrity, keine Signatur.

| Methode | Pfad | Rumpf / Abfrage | Antwort |
|---|---|---|---|
| GET | `v1/user` | | `User` |
| DELETE | `v1/user` | | – |
| POST | `v1/user/sync` | `{email, username, gender, yearOfBirth, territory, newsletter}` | `User` |
| POST | `v1/user/sync` | `{dailyTarget}` | `User` |
| POST | `v1/user/sync` | `{address:{forename, surname, address, additionalAddressInformation, postalCode, city}}` | `User` |
| POST | `v1/user/sync` | `{picture}` | `User` |
| POST | `v1/user/verify-email` | | – |
| POST | `v1/user/reset-password` | `{email}` | – |
| POST | `v1/user/change-email/init` | `{email}` | – |
| POST | `v1/user/change-email/finalize` | | – |
| POST | `v1/user/transferred` | `{email, password}` | – |
| GET | `v1/user/health` | `from`, `until` (JJJJ-MM-TT), `grouping` (Intervall) | `[Health]` |
| POST | `v1/user/health` | `{"health":[{date, steps, distance}]}` | – |
| GET | `v1/user/rank` | `interval`, `withTerritory`, `withGlobal` | `Ranking` |
| GET | `v1/rank` | `interval`, `limit`, `offset`, `territory` | `RankingLeaderboard` |
| GET | `v1/challenge` | | `Challenges` |
| GET | `v1/challenge/{id}` | | `Challenge` |
| PUT | `v1/challenge/{id}/participate` | `{participate: bool}` | – |
| GET | `v1/voucher` | | `[VoucherDetails]` |
| GET | `v1/voucher/{id}` | | `VoucherDetails` |
| GET | `v1/voucher/redeemed` | | `[VoucherDetails]` |
| POST | `v1/voucher/{id}/redeem` | `{code, email, address, pickupStationId}` | `VoucherRedeemed` |
| GET | `v1/user/review` | `year` | `RecapResponse` |
| POST | `v1/feedback` | `{stars, note}` | – |

Intervall: `DAY`, `WEEK`, `MONTH`, `YEAR` (Enum-Name, Retrofit schreibt
`toString()`). Wahrheitswerte als `true`/`false`.

### Schritte hochladen

`POST v1/user/health` mit Tagessummen:

    {"health":[{"date":"2026-10-05","steps":8123,"distance":5686.1}]}

`distance` in **Metern** (Health Connect `Length.inMeters`), `date` im
Format `yyyy-MM-dd`. Kein Feld für die Herkunft der Daten.

Die Android-App schickt bei jedem Lauf (WorkManager, `HealthUploadWorker`)
alle Tage ab „letzter Sync − 7 Tage" (oder „heute − 7", wenn noch nie)
erneut. Daraus folgt vermutlich, dass der Server je Datum **überschreibt**
— bestätigt ist das nicht. Dieser Port lädt deshalb nie einen kleineren Wert
hoch als den, der schon am Server steht (siehe `dienst/src/schritte.rs`).

### Datumsformate

* `LocalDate`: `yyyy-MM-dd`
* `LocalDateTime`: `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`
* `VoucherType`: `gastronomy`, `event`, `donation` (klein)
* `Gender`: `male`, `female`, `diverse`

### Bezirke (`territory`)

Postleitzahl als Zeichenkette: `1010` (1., Innere Stadt) bis `1230`
(23., Liesing) in Zehnerschritten, `9999` = „Außerhalb von Wien".

## Modelle (Feldnamen = JSON-Schlüssel)

* `User`: `_id, username, email, gender, yearOfBirth, territory, newsletter,
  picture, dailyTarget, steps, distance, points, signInProvider, address,
  latestHealth{_id, from, until, steps, distance}, oldestHealth{date, steps,
  distance}, createdAt, updatedAt`
* `Health`: `_id, from, until, steps, distance`
* `Ranking`: `steps, distance, global{rank, stepsToLead, distanceToLead},
  territory{…}`
* `RankingLeaderboard`: `interval, limit, offset, total, list[{_id,
  username, picture, steps, distance, position}]`
* `Challenges`: `available[], joined[], closed[]` von `Challenge`
* `Challenge`: `id, title, description, imageUrl, from, to, stepGoal,
  distanceGoal, totalSteps, totalDistance, hasJoined, challengeIsLocked,
  ranking[{_id, userId, username, picture, steps, distance, position}],
  userRank{…}, createdAt, updatedAt`
* `VoucherDetails`: `id, name, title, description, type, requiredSteps,
  contingent, redeemed, hasCodes, code, listImageUrl, headerImageUrl,
  published{from, until}, pickupStation, pickupStations[{id, name,
  addressStringOverride, address{street, zip, city}}],
  eventPickupRestriction, bankAccount, iban, redeemedVoucher{id, code,
  redeemText, createdAt}, createdAt`
* `VoucherRedeemed`: `id, code, redeemText, createdAt`
* `RecapResponse`: `year, review{totalSteps, totalDistance,
  totalStepsForYear, totalDistanceForYear, dailyTarget, dailyTargetReached,
  daysWithZeroSteps, numberOfChallenges, numberOfVouchers, mostSteps,
  leastSteps, fromCityName, toCityName, nextGoalCityName,
  nextGoalCityDistance}`

### Gutscheine einlösen

* **Gastronomie**: QR-Code im Lokal scannen oder PIN eingeben → `{code}`.
  Dieser Port nimmt nur den PIN (bzw. den Text des QR-Codes).
* **Veranstaltung**: je nach `eventPickupRestriction` (klein geschrieben)
  `"email"` → nur E-Mail, `"post"` → Postadresse oder Abholstelle, sonst
  alles. Rumpf `{email}` oder `{address:{…}}` oder `{pickupStationId}`.
* **Spende**: aus der APK nicht eindeutig abzulesen.

Die App baut den Rumpf in vier Varianten (`CouponRedeemType` CODE, EMAIL,
PICKUPSTATION, ADDRESS); Gson lässt `null`-Felder weg, im Rumpf steht also
immer nur das eine Feld.
