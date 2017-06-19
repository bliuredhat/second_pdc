## Running the playbook


### Install the galaxy roles
```
ansible-galaxy install -r galaxy-roles.txt -p roles/thirdparty
```

#### View installed roles

```
ansible-galaxy list -p roles/thirdparty
```


### Run playbook
```
ansible-playbook -c local -vv dev-env.yml
```

