<script setup lang="ts">
const tagline = 'Shipped end-to-end with azzist'
</script>

<template>
  <main class="hero">
    <section class="hero__inner">
      <h1 class="hero__title">azzist</h1>
      <p class="hero__tagline">{{ tagline }}</p>
      <a class="hero__cta" href="https://github.com/ghulammuzz/azzist-skills">Get started</a>
    </section>
  </main>
</template>

<style>
:root { color-scheme: dark; }
* { box-sizing: border-box; margin: 0; }
body { font-family: ui-sans-serif, system-ui, sans-serif; }

.hero {
  min-height: 100vh;
  display: grid;
  place-items: center;
  background: radial-gradient(120% 120% at 50% 0%, #1b2735 0%, #090a0f 70%);
  color: #f5f7fa;
  padding: 2rem;
}
.hero__inner { text-align: center; max-width: 40rem; }
.hero__title {
  font-size: clamp(3rem, 12vw, 7rem);
  letter-spacing: -0.04em;
  background: linear-gradient(90deg, #6ee7ff, #a78bfa);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}
.hero__tagline { margin-top: 1rem; font-size: clamp(1rem, 3vw, 1.5rem); opacity: 0.8; }
.hero__cta {
  display: inline-block;
  margin-top: 2.5rem;
  padding: 0.85rem 1.75rem;
  border-radius: 999px;
  font-weight: 600;
  text-decoration: none;
  color: #090a0f;
  background: #6ee7ff;
  transition: transform 0.15s ease;
}
.hero__cta:hover { transform: translateY(-2px); }
</style>
