<script setup>
import Ecosystem from './ecosystem.vue'
import Hero from './hero.vue'
import Partners from './partners.vue'
import Highlights from './highlights.vue'
import Features from './features.vue'
import CommunitySection from './community_section.vue'
import { plugins } from '../data/ecosystem';
</script>

<template>
	<div class="flex flex-col">
		<Hero>
			<slot name="start"></slot>
		</Hero>
		<CommunitySection />
	</div>
</template>

<style scoped>
.VPNavBar {
	background-color: transparent !important;
}
</style>