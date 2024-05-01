package models

type Node struct {
	Account Account `json:"account"`
}

type Account struct {
	AccountId   string `json:"accountId"`
	AccountType string `json:"accountType"`
}
