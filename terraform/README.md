# Notas

Precisa exportar a variavel `export AWS_PROFILE=fiapaws`caso seja criado perfis distintos de default nas credenciais da aws.

O que está dentro de bootstrap é para preparar o ambiente com o S3. Ele é necessário para que o terraform guarde o estado da infra.

---
# Criar o bucket s3

### Criar
aws s3api create-bucket --bucket toggle-master-tfstate-dev --region us-east-1 --profile fiapaws

### Apagar
aws s3api delete-bucket --bucket toggle-master-tfstate-dev --region us-east-1

### Verificar se foi criado
aws s3 ls --profile fiapaws | grep toggle-master-tfstate-dev


