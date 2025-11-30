import { supabase } from './supabaseClient.js'

/**
 * Connecte un utilisateur avec email et mot de passe
 * @param {string} email 
 * @param {string} password 
 * @returns {Promise<{success: boolean, error: object, data: object}>}
 */
export async function loginWithEmail(email, password) {
    try {
        const { data, error } = await supabase.auth.signInWithPassword({
            email: email,
            password: password
        })

        if (error) throw error
        return { success: true, data }
    } catch (error) {
        console.error('Login error:', error.message)
        return { success: false, error }
    }
}

/**
 * Inscrit un nouvel utilisateur
 * @param {string} email 
 * @param {string} password 
 * @param {string} role - 'consumer', 'chef', 'courier'
 * @param {string} fullName 
 * @returns {Promise<{success: boolean, error: object, data: object}>}
 */
export async function registerWithEmail(email, password, role, fullName) {
    try {
        const { data, error } = await supabase.auth.signUp({
            email: email,
            password: password,
            options: {
                data: {
                    role: role,
                    full_name: fullName
                }
            }
        })

        if (error) throw error
        return { success: true, data }
    } catch (error) {
        console.error('Registration error:', error.message)
        return { success: false, error }
    }
}

/**
 * Lance la connexion OAuth
 * @param {string} provider - 'google', 'facebook', etc.
 */
export async function loginWithOAuth(provider) {
    try {
        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: provider,
            options: {
                redirectTo: `${window.location.origin}/index.html`
            }
        })
        if (error) throw error
        return { success: true, data }
    } catch (error) {
        console.error('OAuth error:', error.message)
        return { success: false, error }
    }
}

/**
 * Déconnecte l'utilisateur et redirige vers l'accueil
 */
export async function logout() {
    try {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
        window.location.href = 'login.html'
    } catch (error) {
        console.error('Logout error:', error.message)
    }
}

/**
 * Vérifie la session active
 * @returns {Promise<object|null>} Session object or null
 */
export async function checkSession() {
    const { data: { session }, error } = await supabase.auth.getSession()
    if (error) {
        console.error('Session check error:', error.message)
        return null
    }
    return session
}

/**
 * Protège une page privée en vérifiant le rôle
 * @param {Array<string>} allowedRoles - Liste des rôles autorisés ex: ['chef']
 */
export async function protectPrivatePage(allowedRoles = []) {
    const session = await checkSession()

    // 1. Pas de session -> Login
    if (!session) {
        window.location.href = 'login.html'
        return
    }

    // 2. Vérification du rôle
    const userRole = session.user.user_metadata.role || 'consumer'
    
    if (allowedRoles.length > 0 && !allowedRoles.includes(userRole)) {
        // Redirection vers le dashboard approprié si le rôle ne correspond pas
        switch (userRole) {
            case 'chef':
                window.location.href = 'chef-dashboard.html'
                break
            case 'courier':
                window.location.href = 'courier-dashboard.html'
                break
            case 'consumer':
            default:
                window.location.href = 'consumer-dashboard.html'
                break
        }
    }
    
    // Si tout est OK, on affiche les infos utilisateur
    displayUserInfo(session.user)
}

/**
 * Affiche les infos utilisateur dans le DOM
 * @param {object} user 
 */
export function displayUserInfo(user) {
    const nameEls = document.querySelectorAll('.user-name')
    const emailEls = document.querySelectorAll('.user-email')
    const avatarEls = document.querySelectorAll('.user-avatar')

    const fullName = user.user_metadata.full_name || user.email.split('@')[0]
    
    nameEls.forEach(el => el.textContent = fullName)
    emailEls.forEach(el => el.textContent = user.email)
    
    // Gestion avatar (si présent dans metadata ou placeholder)
    const avatarUrl = user.user_metadata.avatar_url || 'https://via.placeholder.com/150'
    avatarEls.forEach(el => {
        if (el.tagName === 'IMG') el.src = avatarUrl
    })
}

// Initialisation automatique : écoute les changements d'état
supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_OUT') {
        // Optionnel : Redirection automatique si déconnexion détectée
        // window.location.href = 'login.html'
    }
})