---
title: "Using Claude"
date: 2025-02-23
updated: 2026-01-28
---

:::: {.tip title="A tl;dr For the Impatient"}
* Revise earlier messages aggressively as you refine what you actually want.

* Quiz for understanding first. Give context, ask a checkpoint question, then ask the real thing.

* Use "problem decomposition": break down the task into bite-sized pieces.
::::

::: note
This post exists because my fiancé wanted advice on a thing and I wrote something quick and dirty to relay this information and she deemed it blog post material. But it had to be redacted a lot to make it fit to post publicly.
:::

Some people have trouble getting LLMs to write useful code for them. Here I explain what I think works and what does not.

### What not to do

The first step in writing a program is identifying the problem you're solving. You sort of know "where you are now" and you sort of know "where you want to end up" and maybe you know some stuff about constraints and requirements between those places.

Do not try to go directly from "the state before you know what your problem even is" to "done". You will have a bad time, like the bad time my example user is having below:

::: chat
@ImpishUser[avatar-impish-user]: hi can you build me a machine learning model that predicts stock prices and also works for crypto and forex and commodities and can you make it better than what hedge funds use and also add sentiment analysis from twitter and reddit and make sure it has really good accuracy like 99% or better and works in real time and maybe add some reinforcement learning and GANs and also make it easy to use thanks ps it needs to work perfectly with no bugs and handle any market conditions

@Chatbot[avatar-chatbot]: Here's a Python script that implements a basic LSTM model for price prediction:

```python
import tensorflow as tf
import pandas as pd

def create_model():
model = tf.keras.Sequential([
tf.keras.layers.LSTM(64, return_sequences=True),
tf.keras.layers.Dense(1)
])
return model

# Main prediction function

def predict_prices(data):
model = create_model()
predictions = model.predict(data)
return predictions
```

You can use this by passing in your market data. Let me know if you need anything else!

@WearyUser[avatar-weary-user]: this doesn't work at all... it's not even complete code and doesn't do anything I asked for. can you make something that actually works?
:::

This conversation sucks! The user dumps multiple complex requirements without any specifics. The core problem is that the *thing they are asking for* is confused.

Worse, they're likely to try to "fix" it by getting into an argument with the chatbot. At which point they'll be given a monkeypatch, which has a good chance of not working. And when they ask for a fix-for-the-fix, now they're getting "a monkeypatch for the already incorrectly monkeypatched code". In the *classic* case, the user ends up alternating between two stable, broken states. The "fixes" just turn broken state A into broken state B (or vice versa).

In my experience people who press on with this strategy end up getting mad at computers. Doing so is unhealthy and doesn't get the work done, so, I'd recommend avoiding this.

### What to do

Use these strategies:

* If you find yourself in an unproductive aggravating loop: **revise** your earlier messages *aggressively* as you refine your understanding of what you want.

* **Quiz** for understanding first. If the task needs the model to interpret complex input correctly, don't immediately ask your real question. First give it the context, then ask a "checkpoint question". If it passes, now ask the real thing. If it fails, you caught the misunderstanding early.

* Use "**problem decomposition**" *aggressively* to break down the task into bite-sized pieces. Have the bot write code that finishes off those bite-sized pieces. The remainder of the post concerns this strategy.

Using LLMs for programming is, ideally, something like having a combination [rubber duck](https://rubberduckdebugging.com/) and grunt-worker. Discuss the task until you *understand* the task. Walk the bot through the process of breaking the task down. Doing this is often easier than doing it yourself.

### More on quizzing

The quiz question should be something where you already know the answer, & a wrong answer reveals a fundamental misunderstanding. e.g. you are going to have it do data retrieval. Data indexing is described relative to values in column a. Row 1 is for column titles. So the values in A are +1 relative to the row numbers. Ask it to retrieve the item in row 55 (or any other row). If it isn't on the same page no sense trying to proceed yet.

### Problem decomposition example

Below is a very heavily redacted conversation that went especially well.

::: note
Throughout this post, chatbot responses have been censored to remove business-specific content. Anywhere you see `[...]` or `[redacted]`, that's where something was cut.
:::

Breaking the problem down is a skill. If you don't know how to do this: ask the model. e.g. `What are the separable stages of this problem?`. We do so here.

::: chat
@CoolUser[avatar-cool-user]: I'm going to show you a script. explain what it does. Note any idiosyncratic language strengths being leveraged that might make it challenging to port to another language. write a documentation/readme document to help a user understand what this is doing and what assumptions it is making or what data shape it is assuming

```r
# ... Several hundred lines of code pasted here ...
```

@Chatbot[avatar-chatbot]: I'll create comprehensive documentation for this script that analyzes what appears to be [redacted].

I've created detailed documentation for the script. Some key points to highlight about what makes this particularly "[...]-like":

```markdown
# Pipeline
## Overview
This script implements [...].

## Dependencies
[...]

## Input Data Requirements
[...]

## Pipeline Stages

### 1.
[...]

### 2.
[...]

### 3.
[...]

### 4.
[...]

## Key Language-Specific Features
[...]

## Assumptions and Limitations
1. Data Structure:
   - [...]
   - [...]
   - [...]

2. Statistical Assumptions:
   - [...]
   - [...]
   - [...]

3. Computational:
   - [...]
   - [...]

## Output
The pipeline produces:
- [...]
- [...]

## Usage Notes
1. Memory Considerations:
   - [...]

2. Computational Time:
   - [...]

3. Customization:
   - [...]

## Idioms and Portability Considerations
When porting to other languages, special attention should be paid to:

1. Formula Interface:
   [...]

2. Data Frame Operations:
   [...]

3. Missing Value Handling:
   [...]

4. Vector Recycling:
   [...]

5. Parameter Expansion:
   [...]

## Error Handling
[...]
```

* The heavy use of [...] is one of the most challenging aspects to port. [...].

* The script leverages [...]. While other languages have similar capabilities, the syntax and behavior can be quite different.

* The handling of [...] is very [...]-specific. [...] has built-in handling that would need to be explicitly implemented in other languages.

* The script uses [...]'s parallel processing capabilities which are designed around [...]'s specific memory model and would need different implementations in other languages.

Would you like me to elaborate on any particular aspect of the documentation or language-specific features?
:::

So now the context contains the input code and a bunch of nitpicking about the exact thing being done. This is good so far. We then gave it a bit more context about other people's past attempts to solve the problem. This seems useful but isn't really worth posting verbatim so I'll skip ahead to the next notable thing:

::: chat
@CoolUser[avatar-cool-user]: next up: would it be easier to comprehend this task if we split it into modules? does the script/library basically do a series of stages of separable/discrete tasks?

@Chatbot[avatar-chatbot]: Yes, looking at the code and documentation, this pipeline can be clearly separated into distinct modules. Let me break down the major stages:

1.

* Core interface: [...]

2.

* Core interface: [...]

3.

* Core interface: [...]

4.

* Core interface: [...]

5.

* Core interface: [...]

6.

* Core interface: [...]

This modular breakdown would make it easier to:

* Port each piece independently

* Test components in isolation

* Potentially optimize/replace individual components

* Maintain clearer separation of concerns

Would you like me to elaborate on any of these modules or start working on a more detailed interface specification for any particular one?
:::

We then hammer out the *exact* shape data is expected to be at the beginning and end of each "module". So far we're just creating "documentation".

::: chat
@CoolUser[avatar-cool-user]: alright. are we clear on the "interfaces" (that is: data shape) coming in and out of each phase? if so, let's proceed to do the data preproccessing module

@Chatbot[avatar-chatbot]: Let me first explicitly document the expected data shapes for each module, then we can proceed with the first module.

```markdown
... lengthy description goes here ...
```

Let's implement the first module. Based on the script, we need [...] for this stage. Here's the implementation:

```R
# ... code here ...
```

I've implemented the preprocessing module following these key principles:

* [...]

Would you like me to:

* Add tests for this module?

* Move on to implementing the second module?

* Add more documentation or modify any part of this implementation?

@CoolUser[avatar-cool-user]: write documentation for this module. what assumptions is it making about what is coming in, what is it doing, and what goes out
what libraries, if any, are used, and are we using vaguely efficient algorithms for stuff that might otherwise get hairy

@Chatbot[avatar-chatbot]: The key points about this implementation are:

* [...]

* [...]


Would you like me to elaborate on any of these aspects or would you like to proceed with implementing the next module?

@CoolUser[avatar-cool-user]: let us proceed, yes. module, interface, documentations
remember that your goal is to avoid adding any constraints or assumptions that aren't present in the base implementation. focus on it being "a port" (of a black box that does x y and z..) and "be reasonably fast". do not add new constraints for convenience
:::

At this point the bot returned a slick, helpful implementation of the first step. And with handholding similar to the above, it was able to do the same for the other five stages. Problem was broken down into tiny little pieces and the questions in the conversation history are pruned for only being the exact question we want to be asking.

If I get an unhelpful answer then it is very likely I have asked the wrong question. The most likely cause of asking the wrong question is "not knowing what it is I actually want". Go back and try again until the conversation is the idealized version of the conversation, where you always ask the exact right questions. This avoids the problem of having endless cascades of "fixes" -- simply generate code that is already either correct or close enough to correct that you can trivially correct it on the spot.

Overall I came away from this task feeling like I understood it better than when I went in, and also like I had to do approximately no work to get that understanding, and to get the work product. I think this generalizes fairly well. As of 2025, chatbots are much better about not hallucinating stuff. So they are extremely good at writing boilerplate, and you can *transform* many tasks *into* boilerplate by breaking them down over and over and over until they assume the *shape* of "write 10 boilerplate things", which you then have the chatbot write. Ez Ez GG!
