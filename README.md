# GreenDelivery - Plateforme de Livraison Éthique et Locale

GreenDelivery est une application web Full Stack Serverless reposant sur l'écosystème **Supabase**. Elle met en relation des consommateurs, des chefs indépendants et des livreurs à vélo via une interface moderne et réactive.

## 🛠 Stack Technique

- **Frontend :** Vanilla JS (ES6+ Modules), CSS3 (Variables, Flexbox/Grid), HTML5.
- **Backend :** Supabase (PostgreSQL).
- **Base de données :** PostgreSQL avec extension **PostGIS** (Géolocalisation).
- **Authentification :** Supabase Auth (Email, OAuth).
- **Sécurité :** Row Level Security (RLS).
- **Temps Réel :** Supabase Realtime (Suivi commandes, Chat).
- **Stockage :** Supabase Storage (Images plats/avatars).
- **Paiement :** Stripe (Intégration Frontend + Edge Functions).

---

## 🚀 Installation et Configuration

### 1. Configuration Supabase

1. Créez un compte et un nouveau projet sur [Supabase](https://supabase.com/).
2. Allez dans l'onglet **SQL Editor**.
3. Copiez l'intégralité du contenu du fichier `schema.sql` fourni dans ce projet.
4. Exécutez le script SQL. Cela va :
   - Activer l'extension PostGIS.
   - Créer les tables (`profiles`, `products`, `orders`, etc.).
   - Configurer les politiques de sécurité RLS.
   - Créer les Triggers pour la gestion des utilisateurs.
   - Créer les fonctions RPC pour la géolocalisation (`get_nearby_dishes`).

### 2. Configuration du Stockage (Storage)

1. Dans le dashboard Supabase, allez dans **Storage**.
2. Créez un nouveau Bucket public nommé `dishes`.
3. Créez un nouveau Bucket public nommé `avatars` (optionnel).
4. Assurez-vous que les politiques d'accès (Policies) permettent l'upload pour les utilisateurs authentifiés (Chefs).

### 3. Connexion Frontend

1. Ouvrez le fichier `supabaseClient.js`.
2. Récupérez vos clés API dans le dashboard Supabase : **Settings > API**.
3. Remplacez les valeurs suivantes :

```javascript
const SUPABASE_URL = 'https://votre-projet.supabase.co'
const SUPABASE_ANON_KEY = 'votre-cle-publique-anon'
```

### 4. Configuration Stripe (Paiement)

1. Créez un compte sur [Stripe](https://stripe.com/).
2. Récupérez votre **Publishable Key** (pk_test_...).
3. Ouvrez le fichier `cart.html`.
4. Cherchez la fonction `initStripe()` et remplacez la clé placeholder par la vôtre.
5. **Note :** Pour que le paiement fonctionne réellement, vous devez déployer une Supabase Edge Function `create-payment-intent` qui communique avec l'API Stripe secrète.

---

## 🌍 Lancement Local

Ce projet utilise des modules ES6 (`type="module"`). Il nécessite un serveur HTTP local pour fonctionner correctement (les imports directs via `file://` seront bloqués par le navigateur CORS).

### Option A : Extension VS Code (Recommandé)
1. Installez l'extension **Live Server** pour VS Code.
2. Faites un clic droit sur `index.html`.
3. Sélectionnez **"Open with Live Server"**.

### Option B : Node.js / Python
Si vous avez Node.js installé :
```bash
npx serve .
```

Ou avec Python :
```bash
python3 -m http.server
```

---

## 📱 Fonctionnalités par Rôle

Pour tester l'application, vous pouvez créer trois comptes différents :

1.  **Consommateur** (`role: consumer`) :
    *   Recherche de plats géolocalisés.
    *   Ajout au panier et paiement.
    *   Suivi de commande en temps réel.

2.  **Chef** (`role: chef`) :
    *   Gestion du menu (Ajout/Modif/Suppression de plats).
    *   Dashboard des ventes.
    *   Gestion des statuts de commande (Cuisine -> Prêt).

3.  **Livreur** (`role: courier`) :
    *   Dashboard avec switch "En ligne/Hors ligne".
    *   Détection des commandes prêtes à proximité (GPS).
    *   Acceptation et livraison de commande.

---

## 📦 Déploiement

Le projet étant statique (HTML/CSS/JS), il peut être déployé sur n'importe quel hébergeur statique :

- **Netlify** (Drag & drop du dossier).
- **Vercel**.
- **GitHub Pages**.

Assurez-vous simplement que l'URL de votre site est ajoutée dans la liste des **Redirect URLs** dans **Supabase > Authentication > URL Configuration** pour que l'OAuth et les redirections fonctionnent.