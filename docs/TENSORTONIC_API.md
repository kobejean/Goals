# TensorTonic API Reference

This document captures reverse-engineered API details for TensorTonic (tensortonic.com) for personal use integration.

## Overview

TensorTonic is an AI/ML problem-solving platform. The API uses cookie-based session authentication via Better Auth.

## Authentication

### Session Cookie Authentication

The API uses Better Auth with the following cookies:

| Cookie | Purpose |
|--------|---------|
| `__Secure-better-auth.session_token` | Primary session token (required for API calls) |
| `__Secure-better-auth.session_data` | Base64-encoded session metadata (user info, expiration) |
| `__Secure-better-auth.state` | Auth flow state management |

**Session token format:** `{token}.{signature}`
- Example: `abc123TokenHere.base64EncodedSignature%3D`

**Session expiration:** ~7 days from creation

### Required Headers for API Calls

```
Cookie: __Secure-better-auth.session_token={token}
Origin: https://www.tensortonic.com
Referer: https://www.tensortonic.com/
```

---

## Endpoints

### 1. Get Session

Validates session and returns current user info.

**Request:**
```
GET https://www.tensortonic.com/api/auth/get-session
```

**Headers:**
```
Cookie: __Secure-better-auth.session_token={token}
```

**Response:** `200 OK`
```json
{
    "session": {
        "expiresAt": "2026-02-06T18:08:59.769Z",
        "token": "abc123SessionToken",
        "createdAt": "2026-01-30T18:08:59.769Z",
        "updatedAt": "2026-01-30T18:08:59.769Z",
        "ipAddress": "xxx.xxx.xxx.xxx",
        "userAgent": "Mozilla/5.0 ...",
        "userId": "exampleUserId123",
        "id": "exampleSessionId456"
    },
    "user": {
        "name": "User Name",
        "email": "user@example.com",
        "emailVerified": false,
        "image": "https://avatars.githubusercontent.com/u/123456?v=4",
        "createdAt": "2026-01-30T18:08:58.860Z",
        "updatedAt": "2026-01-30T18:09:09.570Z",
        "username": "username",
        "profileCompleted": true,
        "termsAccepted": true,
        "termsAcceptedVersion": "2.0",
        "id": "exampleUserId123"
    }
}
```

**Notes:**
- Hosted on Vercel (www.tensortonic.com)
- Same-origin request

---

### 2. Get User Stats

Returns problem-solving statistics for a user.

**Request:**
```
GET https://api.tensortonic.com/api/user/{userId}/stats
```

**Headers:**
```
Cookie: __Secure-better-auth.session_token={token}
Origin: https://www.tensortonic.com
Referer: https://www.tensortonic.com/
```

**Response:** `200 OK`
```json
{
    "status": "success",
    "data": {
        "easy": 0,
        "medium": 0,
        "hard": 0,
        "total": 0,
        "totalEasyProblems": 50,
        "totalMediumProblems": 42,
        "totalHardProblems": 18,
        "researchEasy": 0,
        "researchMedium": 0,
        "researchHard": 0,
        "researchTotal": 0,
        "totalResearchEasyProblems": 22,
        "totalResearchMediumProblems": 42,
        "totalResearchHardProblems": 15
    }
}
```

**Fields:**
| Field | Description |
|-------|-------------|
| `easy`, `medium`, `hard` | Problems solved by difficulty |
| `total` | Total problems solved |
| `totalEasyProblems`, etc. | Total available problems by difficulty |
| `researchEasy`, etc. | Research-track problems solved |
| `totalResearchEasyProblems`, etc. | Total available research problems |

**Rate Limiting:**
- `RateLimit-Limit: 500`
- `RateLimit-Policy: 500;w=900` (500 requests per 15 minutes)
- `RateLimit-Remaining: 492`
- `RateLimit-Reset: 879` (seconds until reset)

**Notes:**
- Hosted on separate API server (api.tensortonic.com)
- Cross-origin request (requires Origin header)
- Server: nginx/1.24.0 (Ubuntu), Express backend

---

### 3. Get User Heatmap

Returns activity heatmap data (submissions by date).

**Request:**
```
GET https://api.tensortonic.com/api/user/{userId}/heatmap
```

**Headers:**
```
Cookie: __Secure-better-auth.session_token={token}
Origin: https://www.tensortonic.com
Referer: https://www.tensortonic.com/
```

**Response:** `200 OK`
```json
{
    "status": "success",
    "data": []
}
```

**Response (when populated):**
```json
{
    "status": "success",
    "data": [
        {
            "date": "2026-01-30",
            "value": 1
        }
    ]
}
```

**Notes:**
- Same rate limiting as stats endpoint
- Empty array when user has no activity
- Field is `value` (not `count`)

---

### 4. Get User Activity

Returns recent problem-solving activity with pagination.

**Request:**
```
GET https://api.tensortonic.com/api/user/{userId}/activity?limit=50
```

**Headers:**
```
Cookie: __Secure-better-auth.session_token={token}
Origin: https://www.tensortonic.com
Referer: https://www.tensortonic.com/
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | int | Max number of activities to return (default: 50) |

**Response:** `200 OK`
```json
{
    "status": "success",
    "data": {
        "activities": [
            {
                "problemId": "sigmoid-numpy",
                "problemTitle": "# <span style=\"font-size: 20px;\">Implement Sigmoid in NumPy</span>",
                "problemSlug": "sigmoid-numpy",
                "difficulty": "Easy",
                "problemType": "free",
                "paperId": null,
                "lastSubmissionAt": "2026-01-30 19:36:25.959"
            }
        ],
        "pagination": {
            "hasMore": false,
            "nextCursor": null
        }
    }
}
```

**Fields:**
| Field | Description |
|-------|-------------|
| `problemId` | Unique problem identifier |
| `problemSlug` | URL-friendly problem name |
| `difficulty` | "Easy", "Medium", or "Hard" |
| `problemType` | "free" or "research" |
| `paperId` | Paper ID for research problems (null for free) |
| `lastSubmissionAt` | Timestamp of last successful submission |
| `pagination.hasMore` | Whether more results are available |
| `pagination.nextCursor` | Cursor for next page (if hasMore is true) |

---

### 5. Get Badge Progress

Returns progress towards badges/tags completion.

**Request:**
```
GET https://api.tensortonic.com/api/user/{userId}/badge-progress
```

**Headers:**
```
Cookie: __Secure-better-auth.session_token={token}
Origin: https://www.tensortonic.com
Referer: https://www.tensortonic.com/
```

**Response:** `200 OK`
```json
{
    "status": "success",
    "data": {
        "completionStatus": [
            {
                "tagId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                "tagName": "Activation Functions",
                "totalProblems": 7,
                "solvedCount": 1,
                "isComplete": false,
                "hasCompletionBadge": false,
                "totalProblemsAtEarn": null,
                "additionalProblemsNeeded": 0
            }
        ],
        "totalMilestoneProgress": {
            "totalSolved": 1,
            "earnedMilestones": [],
            "nextMilestone": 25,
            "progressToNext": 4
        }
    }
}
```

**Tag Categories:**
- Loss Functions (12 problems)
- Activation Functions (7 problems)
- NLP (10 problems)
- Linear Algebra (15 problems)
- Transformers (2 problems)
- Metrics & Evaluation (8 problems)
- Neural Networks (8 problems)
- Optimization (11 problems)
- MLOps (10 problems)
- Classic ML (6 problems)
- Probability and Statistics (11 problems)
- Reinforcement Learning (5 problems)
- 3D Geometry (5 problems)
- Data Processing (15 problems)

**Milestone Thresholds:** 25, 50, 100, etc.

---

## Server Infrastructure

| Host | Purpose | Stack |
|------|---------|-------|
| `www.tensortonic.com` | Frontend + Auth API | Vercel, Next.js |
| `api.tensortonic.com` | Data API | nginx 1.24.0 (Ubuntu), Express |

**API Server:** AWS ap-south-1 region

---

## Implementation Notes

### For iOS Integration

1. **Store credentials:**
   - User ID (from session response)
   - Session token (full cookie value including signature)

2. **Token refresh:**
   - Sessions expire in ~7 days
   - No automatic refresh endpoint discovered
   - User must re-authenticate via browser when expired

3. **Request construction:**
   ```swift
   var request = URLRequest(url: url)
   request.setValue("__Secure-better-auth.session_token=\(sessionToken)", forHTTPHeaderField: "Cookie")
   request.setValue("https://www.tensortonic.com", forHTTPHeaderField: "Origin")
   request.setValue("https://www.tensortonic.com/", forHTTPHeaderField: "Referer")
   ```

4. **Error handling:**
   - 401/403: Session expired, prompt re-auth
   - 429: Rate limited, back off

---

## Implementation Status

**Data Source:** `GoalsKit/Sources/GoalsData/DataSources/TensorTonicDataSource.swift`

**Entities:**
- `TensorTonicStats` - Problem-solving statistics snapshot
- `TensorTonicHeatmapEntry` - Activity heatmap data

**Configuration keys (UserDefaults):**
- `tensorTonicUserId` - User ID from session
- `tensorTonicSessionToken` - Full session token cookie value

**Usage:**
```swift
let settings = DataSourceSettings(
    dataSourceType: .tensorTonic,
    credentials: [
        "userId": "yourUserId",
        "sessionToken": "yourSessionToken.signature"
    ]
)
try await dataSource.configure(settings: settings)
let stats = try await dataSource.fetchStats()
```

---

## Changelog

- **2026-01-30:** Initial documentation from browser network capture
- **2026-01-30:** Added TensorTonicDataSource implementation
- **2026-01-31:** Fixed heatmap response field (`value` not `count`)
- **2026-01-31:** Added activity and badge-progress endpoints