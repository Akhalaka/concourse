package db

import (
	"encoding/json"


	"golang.org/x/crypto/bcrypt"
)

type Team struct {
	Name  string
	Admin bool

	AuthWrapper AuthWrapper

	 BasicAuth    *BasicAuth    `json:"basic_auth"`
	 GitHubAuth   *GitHubAuth   `json:"github_auth"`
	 UAAAuth      *UAAAuth      `json:"uaa_auth"`
	 GenericOAuth *GenericOAuth `json:"genericoauth_auth"`
}


func (auth *BasicAuth) EncryptedJSON() (string, error) {
	var result *BasicAuth
	if auth != nil && auth.BasicAuthUsername != "" && auth.BasicAuthPassword != "" {
		encryptedPw, err := bcrypt.GenerateFromPassword([]byte(auth.BasicAuthPassword), 4)
		if err != nil {
			return "", err
		}
		result = &BasicAuth{
			BasicAuthPassword: string(encryptedPw),
			BasicAuthUsername: auth.BasicAuthUsername,
		}
	}

	json, err := json.Marshal(result)
	return string(json), err
}

type GitHubTeam struct {
	OrganizationName string `json:"organization_name"`
	TeamName         string `json:"team_name"`
}

type SavedTeam struct {
	ID int
	Team
}

type BasicAuth struct {
	BasicAuthUsername string `json:"basic_auth_username"`
	BasicAuthPassword string `json:"basic_auth_password"`
}

type GitHubAuth struct {
	ClientID      string          `json:"client_id"`
	ClientSecret  string          `json:"client_secret"`
	Organizations []string        `json:"organizations"`
	Teams         []GitHubTeam `json:"teams"`
	Users         []string        `json:"users"`
	AuthURL       string          `json:"auth_url"`
	TokenURL      string          `json:"token_url"`
	APIURL        string          `json:"api_url"`
}

type UAAAuth struct {
	ClientID     string   `json:"client_id"`
	ClientSecret string   `json:"client_secret"`
	AuthURL      string   `json:"auth_url"`
	TokenURL     string   `json:"token_url"`
	CFSpaces     []string `json:"cf_spaces"`
	CFURL        string   `json:"cf_url"`
	CFCACert     string   `json:"cf_ca_cert"`
}

type GenericOAuth struct {
	AuthURL       string            `json:"auth_url"`
	AuthURLParams map[string]string `json:"auth_url_params"`
	TokenURL      string            `json:"token_url"`
	ClientID      string            `json:"client_id"`
	ClientSecret  string            `json:"client_secret"`
	DisplayName   string            `json:"display_name"`
	Scope         string            `json:"scope"`
}

type AuthType string
type AuthProvider string

const (
	AuthTypeBasic AuthType = "basicAuth"
	AuthTypeOAuth AuthType = "oauth"

	AuthProviderGithub AuthProvider = "githubAuthProvider"
	AuthProviderUAAAuth AuthProvider = "uaaAuthProvider"
	AuthProviderBasic AuthProvider = "basicAuthProvider"
	AuthTypeOAuth AuthProvider = "oauthProvider"
)

type AuthWrapper struct {
	auths []AuthProvider
}

func NewAuthWrapper(
	authProviders []AuthProvider,
) AuthWrapper {
	return AuthWrapper{
		auths:  authProviders,
	}
}

func (t SavedTeam) GetAuthWrapper () AuthWrapper {
	return t.AuthWrapper
}

