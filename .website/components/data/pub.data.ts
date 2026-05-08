import { defineLoader } from 'vitepress'

export default defineLoader({
    async load(): Promise<string> {
        try {
            const result = await fetch('https://pub.dev/api/packages/loxia', {
                method: 'GET'}).then((x) => x.json())

            return result.latest.version
        } catch (error) {
            console.warn('Fetch pub.dev error')
            console.warn(error)

            return 'unknown'
        }
    }
})
