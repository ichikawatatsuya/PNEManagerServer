<?php

namespace PMS\ApiBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\Controller;

use PMS\ApiBundle\Entity\Sns;
use PMS\ApiBundle\Entity\Domain;
use PMS\ApiBundle\Entity\Server;
use PMS\ApiBundle\Entity\Account;
use PMS\ApiBundle\Entity\SnsPasswords;
use PMS\ApiBundle\Lib\DefaultServerDetermineStrategy;

class SnsController extends BaseApiActionController
{

    public function actionList()
    {
        return array(
            'action' => array(
                'list',
                'apply',
                'detail',
            )
        );
    }

    public function listAction()
    {
        $list = array();
        $snss = $this->getDoctrine()->getRepository('PMSApiBundle:Sns')->findAll();
        foreach ($snss as $sns)
        {
            $list[] = array(
                'domain' => $sns->getDomain(),
                'status' => $sns->getStatus()
            );
        }

        return $this->renderJson($list);
    }

    public function applyAction()
    {
        $params = $this->getRequest()->request;
        $domain = $params->get('domain', null);
        $email = $params->get('email', null);
        $options = $params->get('options', 'mode:plane');
        if (is_null($domain) || is_null($email))
        {
            $param = array();
            if (is_null($domain))
            {
                $param[] = 'domain';
            }
            if (is_null($email))
            {
                $param[] = 'email';
            }

            return $this->renderErrorJson(400, array(
                'param' => $param,
            ));
        }

        if (!preg_match('/^[-\w]+(?:\.[-\w]+)*\/?[a-zA-Z0-9_\-\/.,:;\~\?@&=+$%#!()]$/', $domain))
        {
            return $this->renderErrorJson(400, 'the domain is not valid');
        }

        if (!is_null($this->getDoctrine()->getRepository('PMSApiBundle:Sns')->findOneBy(array('domain' => $domain))))
        {
            return $this->renderErrorJson(400, 'the domain already exist.');
        }

        if (!is_null($this->getDoctrine()->getRepository('PMSApiBundle:Sns')->findOneBy(array('email' => $email))))
        {
            return $this->renderErrorJson(400, 'the email already exist.');
        }

        $em = $this->getDoctrine()->getEntityManager();

        $account = $this->getDoctrine()->getRepository('PMSApiBundle:Account')->findOneBy(array('email' => $email));
        if (is_null($account))
        {
            $account = new Account();
            $account->setEmail($email);

            $validator = $this->get('validator');
            $errors = $validator->validate($account);

/*
            if (0 < count($errors))
            {
                $response = $this->renderErrorJson(400, 'the email is not valid');
                $response->headers->set('Access-Control-Allow-Origin', 'http://form.pne.cc, http://pmstest.tejimaya.net');
                return $response;
            }
*/

            $em->persist($account);
            $em->flush();
        }

        $sds = new DefaultServerDetermineStrategy();

        $dom = new Domain();
        $dom->setDomain($domain);
        $dom->setType('sns');
        $em->persist($dom);
        $em->flush();
        $sns = new Sns();
        $sns->setDomain($domain);
        $sns->setEmail($email);
        $sns->setStatus('accepted');
        $sns->setAccount($account);
        $sns->setServer($this->getDoctrine()->getRepository('PMSApiBundle:Server')->find($sds->determine($this->getDoctrine())));
	$sns->setOptions($options);
        $em->persist($sns);
        $em->flush();

        $response = $this->renderJson(array('result' => true));
        $response->headers->set('Access-Control-Allow-Origin', $this->container->getParameter('deploy_domain'));
        return $response;
    }

    public function detailAction()
    {
        $params = $this->getRequest()->query;
        $domain = $params->get('domain', null);
        if (is_null($domain))
        {
            $param = array();
            if (is_null($domain))
            {
                $param[] = 'domain';
            }

            return $this->renderErrorJson(400, array(
                'param' => $param,
            ));
        }

        $sns = $this->getDoctrine()->getRepository('PMSApiBundle:Sns')->findOneBy(array('domain' => $domain));
        if (is_null($sns))
        {
            return $this->renderErrorJson(400, 'There are no sns');
        }

        return $this->renderJson(array(
            'domain' => $domain,
            'adminEmail' => $sns->getEmail(),
            'status' => $sns->getStatus(),
            'options' => $sns->getOptions(),
        ));
    }

    public function setpassAction()
    {
        $params = $this->getRequest()->request;
        $domain = $params->get('domain');
        $mpassword = $params->get('mpass');
        $apassword = $params->get('apass');

        $sns = $this->getDoctrine()->getRepository('PMSApiBundle:Sns')->findOneBy(array('domain' => $domain));
        $snsPasswords = new SnsPasswords();
        $snsPasswords->setMemberPassword($mpassword);
        $snsPasswords->setAdminPassword($apassword);
        $snsPasswords->setSnsId($sns->getId());

        $em = $this->getDoctrine()->getEntityManager();
        $em->persist($snsPasswords);
        $em->flush();

        $response = $this->renderJson(array('result' => true));
        
        return $response;
    }

    public function deleteAction()
    {
      $params = $this->getRequest()->request;

      $domain = $params->get('domain');

      $em = $this->getDoctrine()->getEntityManager();
      $snsRepository = $em->getRepository('PMSApiBundle:Sns');

      if (!$snsRepository->existsByDomain($domain))
      {
        return $this->renderJson(array('result' => false, 'message' => "指定した{$domian}は存在しません"));
      }

      if (!$snsRepository->deleteByDomain($domain))
      {
        return $this->renderJson(array('result' => false, 'message' => "指定した{$domain}のデータを削除できませんでした"));
      }

      return $this->renderJson(array('result' => true));
    }

}
