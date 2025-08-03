# Family Tree Answer API Examples

This document shows how to use the new AI-powered answer endpoints to ask questions about family members.

## Prerequisites

1. Set your OpenAI API key as an environment variable:
   ```bash
   export OPENAI_API_KEY="your-openai-api-key-here"
   ```

2. Start your Phoenix server:
   ```bash
   mix phx.server
   ```

## API Endpoints

### 1. Ask questions about a specific family member

**Endpoint:** `POST /api/family_members/answer`

**Request Body:**
```json
{
  "person_name": "John Doe",
  "question": "What is his occupation?"
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "person_name": "John Doe",
    "question": "What is his occupation?",
    "answer": "John Doe is a Software Engineer. He currently lives in San Francisco, CA with his wife Jane and their two children Alice and Bob."
  }
}
```

### 2. Ask general questions about the family tree

**Endpoint:** `POST /api/family_members/answer_general`

**Request Body:**
```json
{
  "question": "How many children do John and Jane have?"
}
```

**Example Response:**
```json
{
  "success": true,
  "data": {
    "question": "How many children do John and Jane have?",
    "answer": "John and Jane Doe have two children: Alice Doe (born in 2010) and Bob Doe (born in 2012). Alice is a bright student who loves reading and mathematics, while Bob is an energetic kid who enjoys sports and video games."
  }
}
```

## Example Questions You Can Ask

### About specific people:
- "What is John's occupation?"
- "When was Alice born?"
- "Who are Bob's parents?"
- "Tell me about Jane's background"
- "What hobbies does Alice have?"

### General family questions:
- "How many people are in the family?"
- "Who are the children in the family?"
- "What are the different occupations in the family?"
- "Tell me about the family structure"
- "Who lives in San Francisco?"

## cURL Examples

### Ask about a specific person:
```bash
curl -X POST http://localhost:4000/api/family_members/answer \
  -H "Content-Type: application/json" \
  -d '{
    "person_name": "John Doe",
    "question": "What is his occupation?"
  }'
```

### Ask a general question:
```bash
curl -X POST http://localhost:4000/api/family_members/answer_general \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How many children do John and Jane have?"
  }'
```

## Error Handling

If a person is not found:
```json
{
  "success": false,
  "error": {
    "message": "Person not found. No family member found with the name 'Unknown Person'.",
    "person_name": "Unknown Person",
    "question": "What is their age?"
  }
}
```

If multiple people are found with similar names:
```json
{
  "success": false,
  "error": {
    "message": "Multiple people found with similar names: John Doe, John Smith. Please be more specific.",
    "person_name": "John",
    "question": "What is his occupation?"
  }
}
```

## Features

- **Smart name matching**: The system can find people by full name or partial name
- **Context-aware responses**: The AI uses all available information (bio, relationships, metadata) to provide comprehensive answers
- **Relationship understanding**: The AI can explain family relationships and connections
- **Flexible questioning**: You can ask about any aspect of a person's information
- **General family queries**: Ask questions about the entire family tree structure

## Technical Details

- Uses OpenAI GPT-4o model for generating responses
- Searches the family member database using pattern matching
- Formats all available person data for the AI context
- Handles both specific person queries and general family questions
- Includes proper error handling for edge cases 